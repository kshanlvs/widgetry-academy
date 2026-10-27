import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:widgetry_academy/core/error/failures.dart';
import 'package:widgetry_academy/core/result/result.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';
import 'package:widgetry_academy/features/resume/data/resume_data.dart';
import 'package:widgetry_academy/features/resume/domain/resume.dart';

class MockRepo extends Mock implements ResumeRepository {}

class FakeGateway implements PaymentGateway {
  FakeGateway(this.result);
  GatewayResult result;
  CheckoutOrder? opened;
  @override
  Future<GatewayResult> open(CheckoutOrder order) async {
    opened = order;
    return result;
  }
}

class FakeStore implements StoreBilling {
  FakeStore(this.result, {this.supported = true, this.left = const []});
  StoreResult result;
  @override
  bool supported;
  List<StorePurchased> left;
  String? bought;
  @override
  Future<StoreResult> buy({required String productId, required String accountId}) async {
    bought = productId;
    return result;
  }

  @override
  Future<List<StorePurchased>> unfinished({required String accountId, String prefix = 'course_fee_'}) async => left.where((p) => p.productId.startsWith(prefix)).toList();
}

const order = CheckoutOrder(orderId: 'order_r', amountPaise: 29900, currency: 'INR', keyId: 'rzp_test', name: 'Widgetry Academy', description: 'Resume Premium');
const onPlay = ResumePremium(price: 299, playProductId: 'resume_premium_299', android: AndroidBilling(userChoice: true, accountId: 'acc1', states: ['KERALA']));

void main() {
  late MockRepo repo;
  setUpAll(() => registerFallbackValue(Uint8List(0)));
  setUp(() => repo = MockRepo());

  group('reading the resume API', () {
    test('premium, with the Android billing block', () {
      final p = ResumeJson.premium({
        'active': false, 'expiresAt': '2026-09-01T00:00:00.000Z', 'price': 199, 'days': 30, 'playProductId': 'resume_premium_199', 'maxVersions': 5,
        'android': {'billing': 'user_choice', 'accountId': 'a1', 'states': ['WEST BENGAL', 'KERALA']},
      });
      expect(p.ended, isTrue, reason: 'bought before, now over');
      expect(p.price, 199);
      expect(p.android!.userChoice, isTrue);
      expect(p.android!.states, ['WEST BENGAL', 'KERALA']);
      expect(p.canUse('modern'), isTrue);
      expect(p.canUse('executive'), isFalse);
      expect(ResumeJson.premium({}).android, isNull);
    });

    test('ATS result against a job', () {
      final r = ResumeJson.ats({
        'result': {
          'score': 72.4, 'grade': 'Good', 'mode': 'job',
          'categories': [{'label': 'Keywords', 'score': 18, 'max': 30, 'status': 'ok', 'detail': '6 of 10', 'tips': ['Add Bloc']}],
          'keywords': {'matched': ['Flutter'], 'missing': ['Bloc', 'CI/CD'], 'key': ['Bloc']},
        },
        'job': {'id': 'k3', 'title': 'Flutter Dev', 'company': 'Acme'},
      }, null);
      expect(r.score, 72);
      expect(r.mode, 'job');
      expect(r.categories.single.tips, ['Add Bloc']);
      expect(r.missing, ['Bloc', 'CI/CD']);
      expect(r.key, ['Bloc']);
      expect(r.job!.company, 'Acme');
    });

    test('an imported resume becomes profile fields, with achievements and languages', () {
      final i = ResumeJson.imported({
        'ai': true,
        'profile': {
          'fullName': 'Priya Sharma', 'headline': 'Flutter Developer', 'skills': ['Flutter', 'Dart', ' '], 'found': ['your name', '2 jobs'],
          'achievements': ['Won SIH 2024'], 'languages': ['English', 'Hindi'],
          'experience': [{'company': 'Acme', 'role': 'Developer', 'start': '2023-01', 'end': null, 'points': 'Built X'}],
          'education': [{'degree': 'B.Tech', 'institute': 'IIT', 'year': 2022}],
        },
      });
      expect(i.ai, isTrue);
      expect(i.found, ['your name', '2 jobs']);
      final p = i.profile!;
      expect(p.skills, ['Flutter', 'Dart'], reason: 'blank entries dropped');
      expect(p.achievements, ['Won SIH 2024']);
      expect(p.languages, ['English', 'Hindi']);
      expect(p.experience.single.end, isNull);
      expect(p.education.single.year, 2022);
      expect(p.categories, ['flutter']);
      expect(ResumeJson.imported({'profile': null, 'message': 'No text found'}).profile, isNull);
    });

    test('a saved copy and the tailor reply', () {
      final v = ResumeJson.version({'id': 7, 'name': 'Acme', 'jobTitle': 'Flutter Dev', 'company': 'Acme', 'data': {'about': 'Hi', 'points': [{'index': 0, 'points': 'a\nb'}]}});
      expect(v.subtitle, 'Flutter Dev · Acme');
      expect(v.points, {0: 'a\nb'});
      expect(v.skills, isNull, reason: 'not overridden: uses the main resume skills');
      final t = ResumeJson.ai(const AiRequest(AiAction.tailor), {'summary': 'S', 'jobs': [{'index': 1, 'points': ['p1', 'p2']}], 'addSkills': ['Bloc'], 'gaps': ['Swift']}) as TailorResult;
      expect(t.jobs, {1: ['p1', 'p2']});
      expect(t.addSkills, ['Bloc']);
    });
  });

  group('importing a resume file', () {
    test('only PDF and .docx up to 5 MB reach the server', () async {
      final im = ImportResume(repo);
      final small = Uint8List(10);
      expect((await im(ImportParams(small, fileName: 'cv.doc'))).failureOrNull, isA<ValidationFailure>());
      expect((await im(ImportParams(small, fileName: 'cv.png'))).failureOrNull, isA<ValidationFailure>());
      expect((await im(ImportParams(Uint8List(ImportResume.maxBytes + 1), fileName: 'cv.pdf'))).failureOrNull, isA<ValidationFailure>());
      verifyNever(() => repo.importFile(any(), fileName: any(named: 'fileName'), ai: any(named: 'ai')));
      when(() => repo.importFile(small, fileName: 'CV.PDF', ai: true)).thenAnswer((_) async => const Success(ImportedResume(profile: null)));
      expect((await im(ImportParams(small, fileName: 'CV.PDF', ai: true))).valueOrNull, isNotNull);
    });
  });

  group('buying Resume Premium', () {
    test('without Google\'s choice screen: Razorpay, then active', () async {
      final store = FakeStore(const StoreCancelled(), supported: false);
      final gw = FakeGateway(const GatewaySuccess(paymentId: 'pay_1', orderId: 'order_r', signature: 'sig'));
      when(() => repo.createOrder()).thenAnswer((_) async => const Success(order));
      when(() => repo.verify(orderId: 'order_r', paymentId: 'pay_1', signature: 'sig')).thenAnswer((_) async => const Success(ResumePremium(active: true)));
      final r = await BuyResumePremium(repo, gw, store)(const BuyPremiumRequest(onPlay));
      expect(r.valueOrNull, BuyOutcome.active);
      expect(gw.opened, order);
      expect(store.bought, isNull);
    });

    test('Google Play: needs the state first, then a paid purchase is active', () async {
      final store = FakeStore(const StorePurchased(productId: 'resume_premium_299', token: 'tok'));
      final buy = BuyResumePremium(repo, FakeGateway(const GatewayCancelled()), store);
      expect(BuyResumePremium.usesStore(onPlay, store), isTrue);
      expect((await buy(const BuyPremiumRequest(onPlay))).failureOrNull, isA<ValidationFailure>());
      when(() => repo.startPlayPurchase()).thenAnswer((_) async => const Success('resume_premium_299'));
      when(() => repo.verifyStorePurchase(productId: 'resume_premium_299', token: 'tok')).thenAnswer((_) async => const Success('paid'));
      expect((await buy(const BuyPremiumRequest(onPlay, state: 'KERALA'))).valueOrNull, BuyOutcome.active);
      expect(store.bought, 'resume_premium_299');
    });

    test('choosing Razorpay on Google\'s screen sends the external token and state', () async {
      final store = FakeStore(const StoreChoseRazorpay('ext_tok'));
      when(() => repo.startPlayPurchase()).thenAnswer((_) async => const Success('resume_premium_299'));
      when(() => repo.createOrder(externalToken: 'ext_tok', state: 'KERALA')).thenAnswer((_) async => const Success(order));
      final r = await BuyResumePremium(repo, FakeGateway(const GatewayPending()), store)(const BuyPremiumRequest(onPlay, state: 'KERALA'));
      expect(r.valueOrNull, BuyOutcome.pending);
    });

    test('unconfirmed Play purchases of Resume Premium are confirmed; course ones are left alone', () async {
      final store = FakeStore(const StoreCancelled(), left: const [StorePurchased(productId: 'resume_premium_299', token: 't1'), StorePurchased(productId: 'course_fee_full', token: 't2')]);
      when(() => repo.verifyStorePurchase(productId: 'resume_premium_299', token: 't1')).thenAnswer((_) async => const Success('paid'));
      expect(await RecoverResumePurchases(repo, store)(onPlay.android!), 1);
      verifyNever(() => repo.verifyStorePurchase(productId: 'course_fee_full', token: any(named: 'token')));
    });
  });
}
