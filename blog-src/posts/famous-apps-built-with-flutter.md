---
title: "Famous Apps Built with Flutter (2026): Google Pay, BMW, Toyota and More"
description: Eight well-known apps built with Flutter, from Google Pay and Google Classroom to BMW and Toyota cars, with real numbers and what each teaches developers.
date: 2026-10-18
tag: Learning
keywords: apps built with flutter, famous flutter apps, companies using flutter, flutter app examples, is google pay built with flutter, flutter in production
cta: course
---

"Is Flutter used in real apps, or only in tutorials?" I hear this question from almost every student who joins a Flutter class. It's a fair question. Before you spend months learning something, you want to know that serious companies trust it.

They do. Below are eight well-known apps built with Flutter, from apps you probably used this week to the screen inside a new car. For each one I've included the numbers the company itself published, and what it means for you as a developer.

## Quick list: famous apps built with Flutter

| App | Company | What it is |
|---|---|---|
| Google Pay | Google | Payments app, rebuilt in Flutter |
| Google Classroom | Google | School app used by teachers and students |
| My BMW | BMW | Car owner app in 47 countries |
| Toyota and Lexus infotainment | Toyota | The touch screen inside new cars |
| Nubank | Nubank | One of the world's largest digital banks |
| Xianyu | Alibaba | China's largest second-hand marketplace |
| eBay Motors | eBay | App for buying and selling vehicles |
| Ubuntu desktop installer | Canonical | The installer for the Ubuntu operating system |

## 1. Google Pay

If you're in India, you have probably used this one. Google Pay had grown to about **1.7 million lines of code** across separate Android and iOS apps, and every new feature had to be built twice. So Google rebuilt the app in Flutter.

According to [Flutter's case study](https://flutter.cn/showcase/google-pay):

- The code shrank from 1.7 million to about 1.1 million lines, **around 35% smaller**.
- The team estimated it **saved 60–70% of engineering time**.
- Nearly 300 features were rebuilt, and the new app was relaunched in **India** and the US on Flutter.
- The app serves over **100 million monthly active users**.

**Lesson for you:** Flutter isn't only for small apps. A payments app, where bugs cost real money, runs on it at a huge scale.

## 2. Google Classroom

Google Classroom is used by about **150 million teachers and students**. The team rewrote the whole Android and iOS app in Flutter over about two years, launching on iOS in June 2023 and on Android in January 2024.

The results, from the [Google Classroom story on the Flutter blog](https://flutter.dev/blog/cross-platform-development-with-flutter-how-google-classroom-gets-teachers-and-students-on-the):

- App launch time dropped by **80%**.
- Engineering time for new features fell by about **two-thirds**.
- New features needed **at least 50% fewer lines of code**.

**Lesson for you:** Notice that some pieces stayed native (for example, the drawing and annotation feature uses native libraries through plugins). Real Flutter apps mix Flutter with platform code. Learning how plugins and platform channels work is a real job skill.

## 3. My BMW

BMW replaced its older BMW and MINI Connected apps with the **My BMW app**, written in Flutter from a single codebase for iOS and Android. It launched in July 2020 and is available in **47 countries on five continents**.

From the [BMW case study](https://flutter.cn/showcase/bmw/), the project took **less than a year** from start to launch, and BMW's build system produces **96 app variants** (for different brands, countries and regulations) from that one codebase, built and tested automatically several times a day.

**Lesson for you:** Big companies care about automation. CI/CD, flavors and automated testing are what turn one Flutter codebase into dozens of apps.

## 4. Toyota and Lexus car screens

This one surprises people: Flutter isn't only on phones. Toyota uses Flutter for the **infotainment system**, the touch screen inside the car. It debuts in the **2026 Toyota RAV4** and **2026 Lexus ES**, with more models planned.

In [Toyota's story on the Flutter showcase](https://flutter.dev/showcase/toyota), the team explains that Flutter made the screen feel "more like a modern device than a kiosk", that it's open source (many alternatives charge per seat), and that Dart was easy for their team to learn.

**Lesson for you:** Flutter runs on embedded devices too: cars, kiosks and smart displays. That's a growing area for Flutter jobs.

## 5. Nubank

Nubank is one of the largest digital banks in the world, based in Brazil. Before choosing a framework, it compared Kotlin Native, React Native and Flutter against 11 criteria. Flutter came out ahead on developer experience, documentation and API stability, and **all new features are now written in Flutter**.

From the [Nubank case study](https://flutter.cn/showcase/nubank/):

- Flutter pull requests merge in about **9.9 minutes on average**, compared with 70 minutes across all platforms.
- A new life insurance feature launched in **three months**, Nubank's fastest launch at the time.
- New engineers can contribute **within days**.

**Lesson for you:** Banks are careful about technology. When a bank chooses Flutter after a formal comparison, that's a strong signal it's a safe skill to learn.

## 6. Xianyu by Alibaba

Xianyu is **China's largest second-hand marketplace**, built by Alibaba. According to the [Alibaba showcase page](https://flutter.dev/showcase/alibaba-group), the team chose Flutter to make an app that was "consistent across platforms, had beautiful graphics, and still loaded fast". Alibaba's Xianyu team was one of the earliest large companies to use Flutter in production.

**Lesson for you:** Shopping apps with long product lists and lots of images are exactly what Flutter is good at. That's why we build a shopping app as the final project in our course.

## 7. eBay Motors

eBay built the **eBay Motors** app for Android and iOS in Flutter, starting in December 2018, with the goal of going from idea to both app stores in under a year. A beta reached eBay's CEO within three months.

The [eBay engineering article](https://innovation.ebayinc.com/stories/ebay-motors-accelerating-with-fluttertm/) shows how much code was shared:

- **98.3%** of the code was Dart (about 220,000 lines).
- Only **0.6%** was Kotlin, Java, Swift or Objective-C.
- Most of the team surveyed said Flutter development was **more than twice as fast** as their previous platform.

**Lesson for you:** "Write once, run on both" is real. In a well-built Flutter app, platform-specific code is a tiny part of the project.

## 8. Ubuntu desktop installer

Flutter also runs on desktops. When Canonical redesigned the installer for **Ubuntu**, one of the most popular Linux operating systems, it [announced that the new installer was being made with Flutter](https://canonical.com/blog/flutter-and-ubuntu-so-far?format=md).

**Lesson for you:** With one skill you can build for Android, iOS, the web, Windows, macOS and Linux. Few frameworks can say that.

## What these apps have in common

Looking across all eight, a pattern appears:

- **One codebase, many platforms.** Every company here wanted to stop building the same feature twice.
- **Faster delivery.** Google Pay, Classroom, Nubank and eBay all report shipping features noticeably faster.
- **Native code still matters a little.** Plugins, platform channels and native builds show up in almost every case.
- **Testing and automation are serious.** BMW builds 96 variants automatically; eBay enforces 100% test coverage.

## What this means if you're learning Flutter

If you're a student or switching careers, here's what to take from this:

1. **Flutter is a safe bet.** Google, BMW, Toyota, Alibaba and major banks rely on it in production.
2. **Learn beyond widgets.** State management, APIs, testing and CI/CD are what companies like these actually use.
3. **Build an app that looks real.** A shopping app or a payments-style app shows the same skills these teams need.
4. **Look at the jobs.** Companies hiring Flutter developers in India are posting every week. You can browse them on [Widgetry Jobs](../jobs.html), and read our guide to [getting your first Flutter internship or job](flutter-internship-fresher-jobs.html).

## Frequently asked questions

### Is Google Pay built with Flutter?

Yes. Google rebuilt the Google Pay app in Flutter, reducing its code from about 1.7 million to 1.1 million lines, and relaunched it in India and the US on Flutter.

### Which big companies use Flutter?

Google (Google Pay, Google Classroom), BMW, Toyota, Alibaba, eBay, Nubank and Canonical (Ubuntu) all use Flutter in production apps, along with many startups and agencies in India.

### Can Flutter be used for large apps?

Yes. Google Pay serves over 100 million monthly users and Google Classroom about 150 million teachers and students, both on Flutter. Large apps need good architecture and testing, which is true for any framework.

### Is Flutter only for mobile apps?

No. Flutter builds apps for Android, iOS, the web, Windows, macOS and Linux, and it also runs on embedded screens such as Toyota's in-car infotainment system.

### Is it worth learning Flutter in 2026?

If you want to build apps, yes. The examples above show long-term commitment from large companies. Read [Flutter vs React Native jobs in India](flutter-vs-react-native-jobs.html) for a job-market comparison, and [how to become a Flutter developer](how-to-become-flutter-developer.html) for a step-by-step plan.
