/* ===== Widgetry Academy: help chatbot =====
   All questions and answers live in this file. No database reads or writes.
   Answers never state fees, dates, timings or seat counts: for those, the bot
   points to the live section of the page, so it is always correct.
   To edit an answer, change the INTENTS list below and redeploy. */
(function () {
  "use strict";
  if (window.__wgChat) return;
  window.__wgChat = true;

  var C = window.WIDGETRY || {};
  var WA = String(C.whatsapp || "").replace(/\D/g, "");
  var onHome = !!document.getElementById("fees");
  var HOME = onHome ? "" : "/";
  var COURSE = "Flutter in 10 Days";

  /* ---------- Answers ----------
     k: words or phrases that point to this answer (lower case, English + common Hinglish)
     a: answer text (short, stable facts only)
     act: buttons  [label, type, target]   type: "go" = scroll to a page section, "link" = open a page, "wa" = WhatsApp
     rel: related questions shown as chips after the answer */
  var INTENTS = [
    { id: "fee", q: "What's the fee?",
      k: ["fee", "fees", "price", "cost", "charges", "how much", "kitna", "kitne", "paisa", "paise", "rupees", "rs ", "₹", "amount", "early bird", "discount", "offer", "coupon", "scholarship"],
      a: "You can pay in full, or book your seat with a part payment and pay the rest later. The current fee and any early-bird offer are always shown in the Fees section.",
      act: [["See fees", "go", "fees"], ["Reserve my seat", "go", "register"]], rel: ["pay", "refund", "batch"] },
    { id: "pay", q: "How do I pay?",
      k: ["pay", "payment", "upi", "card", "net banking", "netbanking", "razorpay", "gpay", "phonepe", "paytm", "emi", "installment", "instalment"],
      a: "Payments go through Razorpay, so you can pay securely with UPI, debit or credit card, or net banking. Fill in the short registration form first, then pay to confirm your seat.",
      act: [["See payment options", "go", "fees"]], rel: ["refund", "register"] },
    { id: "refund", q: "Is there a refund?",
      k: ["refund", "money back", "cancel", "cancellation", "return"],
      a: "Yes. If the course isn't right for you, you can get a refund within the first sessions. The exact rules are in our refund policy.",
      act: [["Read refund policy", "link", "refund.html"]], rel: ["demo", "fee"] },
    { id: "batch", q: "When does the next batch start?",
      k: ["when", "start", "starting", "next batch", "batch", "date", "dates", "timing", "timings", "time", "schedule", "kab", "online", "offline", "mode", "google meet", "zoom", "location", "where", "venue", "class time"],
      a: "Classes run live on Saturdays and Sundays, so they fit around school and college. The next batch's start date, timing and format are on the batch card, kept up to date.",
      act: [["See next batch", "go", "nextBatch"], ["Ask on WhatsApp", "wa", "Hi! I'd like details of the next batch of Flutter in 10 Days."]], rel: ["duration", "missed", "demo"] },
    { id: "duration", q: "How long is the course?",
      k: ["how long", "duration", "how many sessions", "how many classes", "sessions", "weeks", "days", "10 days", "ten days", "length"],
      a: "It's 10 live sessions spread over 5 weekends: one session every Saturday and Sunday. Each session is mostly hands-on building, with time for doubts.",
      act: [["See the syllabus", "go", "schedule"]], rel: ["batch", "build", "missed"] },
    { id: "missed", q: "What if I miss a class?",
      k: ["miss", "missed", "absent", "skip", "can't attend", "cant attend", "not able to attend", "recording", "recorded"],
      a: "No problem. Message us and we'll help you catch up before the next class, so you don't fall behind.",
      act: [["Message on WhatsApp", "wa", "Hi! I may miss a class of Flutter in 10 Days. How can I catch up?"]], rel: ["batchsize", "certificate"] },
    { id: "batchsize", q: "How many students per batch?",
      k: ["batch size", "how many students", "students per", "class size", "crowd", "individual attention", "personal attention"],
      a: "We keep batches small, so every student gets individual attention and doubts are solved in class.",
      act: [], rel: ["mentor", "beginner"] },
    { id: "beginner", q: "I've never coded. Can I join?",
      k: ["never coded", "no coding", "beginner", "beginners", "zero", "no experience", "new to coding", "don't know coding", "dont know coding", "non coder", "non-coder", "from scratch", "basic", "programming knowledge", "coding knowledge"],
      a: "Yes. The course starts from zero: Day 1 is setup and your first app, and Day 2 covers the Dart basics you need. If you can use a computer comfortably, you can follow along.",
      act: [["See the syllabus", "go", "schedule"]], rel: ["eligibility", "need", "build"] },
    { id: "eligibility", q: "Who can join?",
      k: ["who can join", "can i join", "eligible", "eligibility", "class 10", "class 11", "class 12", "10th", "11th", "12th", "school student", "college", "graduate", "btech", "b.tech", "bca", "bsc", "bcom", "age", "stream", "commerce", "arts", "non it", "non-it"],
      a: "Anyone from Class 10 through graduation, in any stream: science, commerce or arts. Recent graduates are welcome too.",
      act: [["Reserve my seat", "go", "register"]], rel: ["beginner", "school", "need"] },
    { id: "need", q: "What do I need?",
      k: ["need", "laptop", "computer", "pc", "ram", "requirement", "requirements", "system", "windows", "linux", "phone", "android", "mobile", "device", "software", "install"],
      a: "A laptop with Windows, macOS or Linux (8 GB RAM recommended) and an Android phone if you have one. We help you install everything on Day 1, and all the tools are free.",
      act: [], rel: ["mac", "beginner"] },
    { id: "mac", q: "Do I need a Mac or iPhone?",
      k: ["mac", "macbook", "iphone", "ios", "apple"],
      a: "No. Any Windows, macOS or Linux laptop works. We build and test on Android, and the same Flutter code runs on iOS too.",
      act: [], rel: ["need", "flutter"] },
    { id: "school", q: "Can I do this alongside school or college?",
      k: ["alongside", "with school", "with college", "exams", "exam", "weekdays", "weekend", "weekends", "saturday", "sunday", "busy", "working"],
      a: "Yes. Classes are only on weekends, so they don't clash with school, college or exams on weekdays.",
      act: [["See next batch", "go", "nextBatch"]], rel: ["batch", "missed"] },
    { id: "build", q: "What will I build?",
      k: ["build", "what will i build", "will i build", "will we build", "project", "make", "app will", "what app", "e-commerce", "ecommerce", "shopping", "portfolio project", "capstone", "outcome", "learn", "what will i learn"],
      a: "One real app, built step by step: designed screens, a product list with live data from the internet, wishlist and cart, a checkout form, and login with cloud data using Firebase. On Day 10 you install it on your phone and put the code on GitHub.",
      act: [["See the syllabus", "go", "schedule"]], rel: ["certificate", "career", "syllabus"] },
    { id: "syllabus", q: "What's in the syllabus?",
      k: ["syllabus", "curriculum", "topics", "modules", "content", "covered", "cover", "brochure", "pdf", "firebase", "api", "github", "state management", "setstate"],
      a: "Five modules, two sessions each: 1) Getting started and Dart basics, 2) Designing screens, 3) Lists, navigation and live data, 4) Saving data and Firebase login, 5) Polish, build the app and demo day.",
      act: [["See the syllabus", "go", "schedule"], ["Download brochure", "link", "Widgetry-Academy-Flutter-Brochure.pdf"]], rel: ["build", "duration"] },
    { id: "certificate", q: "Do I get a certificate?",
      k: ["certificate", "certification", "certified", "certify"],
      a: "Yes, a Widgetry Academy certificate with a unique ID you can add to your resume and LinkedIn. To earn it, attend at least 8 of the 10 sessions, try the practice tasks, and present your app on demo day.",
      act: [["See the certificate", "go", "certificate"]], rel: ["career", "build"] },
    { id: "career", q: "Will this help my career?",
      k: ["career", "job", "jobs", "get a job", "getting job", "getting a job", "placement", "placements", "internship", "salary", "resume", "cv", "linkedin", "hire", "hiring", "future"],
      a: "You leave with a real app, a GitHub portfolio and guidance on presenting them in your resume and LinkedIn. We don't promise placements, but you'll have proof you can build, which is what recruiters look for. The Professional Flutter Program (coming soon) goes further for job-readiness.",
      act: [], rel: ["build", "certificate", "flutter"] },
    { id: "mentor", q: "Who teaches the course?",
      k: ["who teaches", "teacher", "trainer", "mentor", "instructor", "faculty", "kishan", "sir", "tutor", "taught by", "experience"],
      a: "Kishan Kumar Sharma, a Senior Software Engineer at Relevance Lab with an MCA and 5+ years of building Flutter apps. He has worked on apps with 50M+ downloads, including Tata Neu, and teaches the way real teams build apps.",
      act: [["Meet your mentor", "go", "mentor"]], rel: ["batchsize", "demo"] },
    { id: "demo", q: "Is there a free demo class?",
      k: ["demo", "trial", "free class", "try", "sample class", "free session", "first class free"],
      a: "Yes. You can join a free demo class first, with no commitment. Message us on WhatsApp and we'll share the next demo slot.",
      act: [["Book demo on WhatsApp", "wa", "Hi! I'd like to book the free demo class for Flutter in 10 Days."]], rel: ["fee", "batch"] },
    { id: "parents", q: "Can parents attend?",
      k: ["parent", "parents", "mother", "father", "mom", "dad", "guardian", "my son", "my daughter", "my child", "my kid"],
      a: "Yes. Parents can follow the curriculum and are warmly invited to demo day to see the app their child built.",
      act: [["Ask on WhatsApp", "wa", "Hi! I'm a parent and have a question about Flutter in 10 Days."]], rel: ["eligibility", "school"] },
    { id: "register", q: "How do I register?",
      k: ["register", "registration", "enroll", "enrol", "join", "sign up", "signup", "admission", "book seat", "reserve", "apply"],
      a: "Tap Reserve my seat, fill in the short form (it takes under a minute), then pay to confirm. You'll get batch details on WhatsApp.",
      act: [["Reserve my seat", "go", "register"]], rel: ["fee", "pay"] },
    { id: "flutter", q: "What is Flutter?",
      k: ["what is flutter", "flutter", "dart", "why flutter", "google", "cross platform", "cross-platform"],
      a: "Flutter is Google's free toolkit for building Android, iOS and web apps from one codebase. Apps like Google Pay use it, and it's beginner-friendly: hot reload shows every change on your phone instantly.",
      act: [], rel: ["build", "career"] },
    { id: "courses", q: "Do you have other courses?",
      k: ["other course", "other courses", "more courses", "full stack", "fullstack", "web development", "react", ".net", "javascript", "advanced", "next course", "professional"],
      a: "Flutter in 10 Days is open now. A Full-Stack Web Development course and the Professional Flutter Program are coming soon.",
      act: [["See courses", "go", "courses"]], rel: ["career", "build"] },
    { id: "teach", q: "Can I teach at Widgetry?",
      k: ["i want to teach", "want to teach", "teach at", "teach with", "teach here", "become mentor", "become a mentor", "mentor apply", "part time teaching", "trainer job", "work with you", "collaborate"],
      a: "If you're a working IT professional who enjoys teaching, apply to become a mentor. We handle students, payments and marketing; you teach.",
      act: [["Apply as a mentor", "link", "pages/apply-mentor.html"]], rel: ["mentor"] },
    { id: "contact", q: "How do I contact you?",
      k: ["contact", "call", "phone number", "number", "whatsapp", "email", "talk to", "speak", "human", "person", "support", "help me", "reach"],
      a: "The quickest way is WhatsApp. We usually reply within a few hours. You can also use the contact page.",
      act: [["Chat on WhatsApp", "wa", "Hi! I have a question about Flutter in 10 Days."], ["Contact page", "link", "contact.html"]], rel: ["demo", "register"] },
    { id: "hello", q: "Hi",
      k: ["hi", "hello", "hey", "hii", "namaste", "good morning", "good evening", "good afternoon"],
      a: "Hi! Ask me anything about Flutter in 10 Days, or pick a question below.",
      act: [], rel: ["fee", "batch", "beginner"] },
    { id: "thanks", q: "Thanks",
      k: ["thank", "thanks", "thank you", "thx", "ok thanks", "great", "awesome", "cool"],
      a: "You're welcome! If anything else comes up, I'm right here.",
      act: [["Reserve my seat", "go", "register"]], rel: ["demo", "contact"] }
  ];
  var BY = {}; INTENTS.forEach(function (x) { BY[x.id] = x; });
  var STARTERS = ["fee", "batch", "beginner", "demo", "build", "certificate"];

  /* ---------- Matching ---------- */
  function norm(s) { return " " + String(s).toLowerCase().replace(/[^a-z0-9₹.+\- ]+/g, " ").replace(/\s+/g, " ").trim() + " "; }
  // Common words that hint at a topic but should not decide it on their own
  var GENERIC = {}; ["when","time","where","can i join","start","starting","join","apply","need","learn","make","try","experience","future","system","content","covered","google","phone","number","help me","working","busy","days","weeks","sessions","basic","app will","build","date","great","cool","pc","age","mobile","device","software","install","reach","person","call","sir","hire","return","card","offer","project","outcome","flutter","weekend","weekends","saturday","sunday"].forEach(function (w) { GENERIC[w] = 1; });
  function match(text) {
    var t = norm(text), best = null, bestScore = 0;
    INTENTS.forEach(function (it) {
      var score = 0;
      it.k.forEach(function (kw) {
        var k = kw.trim().toLowerCase();
        var hit = k.length <= 3 ? t.indexOf(" " + k + " ") > -1 : t.indexOf(k) > -1;
        if (hit) score += GENERIC[k] ? 0.6 : 1 + k.split(" ").length * 0.6 + (k.length > 6 ? 0.3 : 0);
      });
      if (it.id === "hello" || it.id === "thanks") score *= 0.7; // greetings lose to real questions
      if (score > bestScore) { bestScore = score; best = it; }
    });
    return bestScore >= 1 ? best : null;
  }

  /* ---------- Styles (use the page's own colour tokens, with fallbacks) ---------- */
  var css = "" +
  "#waFloat{display:none!important}" +
  ".wgc,.wgc *{box-sizing:border-box}" +
  ".wgc{--c-bg:var(--surface,#fff);--c-ink:var(--ink,#0e1f1a);--c-muted:var(--muted,#56695f);--c-line:var(--line,#d8e2dc);--c-acc:var(--accent,#0f6b56);--c-acc-ink:var(--accent-ink,#fff);--c-deep:var(--deep,#0c2a23);--c-gold:var(--accent-2,#f2a900);--c-soft:var(--soft,#e3efe9);font-family:var(--body,'DM Sans',system-ui,sans-serif);color:var(--c-ink)}" +
  ".wgc-launch{position:fixed;right:20px;bottom:calc(20px + env(safe-area-inset-bottom,0px));z-index:2147483000;display:flex;align-items:center;gap:10px;border:0;cursor:pointer;background:var(--c-deep);color:#fff;border-radius:999px;padding:0 20px 0 14px;height:58px;font:700 15px/1 var(--body,'DM Sans',system-ui,sans-serif);box-shadow:0 14px 34px -10px rgba(4,30,22,.55),0 0 0 1px rgba(255,255,255,.08) inset;transition:transform .2s ease,box-shadow .2s ease}" +
  ".wgc-launch:hover{transform:translateY(-2px)}" +
  ".wgc-launch:focus-visible,.wgc button:focus-visible,.wgc a:focus-visible{outline:3px solid var(--c-gold);outline-offset:2px}" +
  ".wgc-launch .ic{width:34px;height:34px;border-radius:50%;background:var(--c-gold);display:grid;place-items:center;flex:none}" +
  ".wgc-launch .dot{position:absolute;top:8px;left:38px;width:12px;height:12px;border-radius:50%;background:#ff5a4f;border:2px solid var(--c-deep)}" +
  ".wgc-hint{position:fixed;right:20px;bottom:calc(90px + env(safe-area-inset-bottom,0px));z-index:2147483000;max-width:260px;background:var(--c-bg);color:var(--c-ink);border:1px solid var(--c-line);border-radius:18px 18px 4px 18px;padding:12px 36px 12px 14px;font-size:14px;line-height:1.4;box-shadow:0 18px 40px -16px rgba(4,30,22,.35);cursor:pointer;animation:wgcIn .35s ease both}" +
  ".wgc-hint b{display:block;margin-bottom:2px}" +
  ".wgc-hint .x{position:absolute;top:6px;right:6px;width:26px;height:26px;border:0;background:transparent;color:var(--c-muted);border-radius:50%;cursor:pointer;font-size:16px;line-height:1}" +
  ".wgc-panel{position:fixed;right:20px;bottom:calc(92px + env(safe-area-inset-bottom,0px));z-index:2147483001;width:392px;height:min(640px,calc(100vh - 120px));display:flex;flex-direction:column;background:var(--c-bg);border:1px solid var(--c-line);border-radius:24px;overflow:hidden;box-shadow:0 30px 70px -20px rgba(4,30,22,.45);transform-origin:bottom right;animation:wgcPop .26s cubic-bezier(.2,.8,.2,1) both}" +
  ".wgc-panel[hidden]{display:none!important}" +
  ".wgc-head{background:var(--c-deep);color:#fff;padding:16px 16px 16px 18px;display:flex;align-items:center;gap:12px;flex:none}" +
  ".wgc-logo{display:grid;grid-template-columns:repeat(2,13px);gap:4px;padding:8px;border-radius:14px;background:rgba(255,255,255,.08);flex:none}" +
  ".wgc-logo i{width:13px;height:13px;border-radius:4px;display:block}" +
  ".wgc-title{flex:1;min-width:0}" +
  ".wgc-title b{display:block;font:700 16px/1.2 var(--display,'Unbounded',system-ui,sans-serif);letter-spacing:-.01em}" +
  ".wgc-title span{display:flex;align-items:center;gap:6px;font-size:13px;color:rgba(255,255,255,.72);margin-top:3px}" +
  ".wgc-title span::before{content:'';width:8px;height:8px;border-radius:50%;background:#3fc79f;box-shadow:0 0 0 3px rgba(63,199,159,.25)}" +
  ".wgc-close{width:38px;height:38px;border-radius:12px;border:0;background:rgba(255,255,255,.1);color:#fff;cursor:pointer;display:grid;place-items:center;flex:none}" +
  ".wgc-close:hover{background:rgba(255,255,255,.18)}" +
  ".wgc-body{flex:1;min-height:0;overflow-y:auto;padding:18px 16px 8px;display:flex;flex-direction:column;gap:10px;background:linear-gradient(var(--c-bg),var(--c-bg)) padding-box;scroll-behavior:smooth}" +
  ".wgc-msg{max-width:86%;padding:11px 14px;border-radius:18px;font-size:15px;line-height:1.5;animation:wgcIn .25s ease both;overflow-wrap:anywhere}" +
  ".wgc-msg.bot{align-self:flex-start;background:var(--c-soft);border-bottom-left-radius:6px}" +
  ".wgc-msg.me{align-self:flex-end;background:var(--c-acc);color:var(--c-acc-ink);border-bottom-right-radius:6px}" +
  ".wgc-acts{display:flex;flex-wrap:wrap;gap:8px;margin-top:10px}" +
  ".wgc-act{display:inline-flex;align-items:center;gap:6px;border:0;cursor:pointer;text-decoration:none;font:700 13.5px/1 var(--body,'DM Sans',system-ui,sans-serif);padding:10px 14px;border-radius:12px;background:var(--c-deep);color:#fff}" +
  ".wgc-act.wa{background:#1fa855;color:#fff}" +
  ".wgc-act.alt{background:transparent;color:var(--c-ink);box-shadow:inset 0 0 0 1.5px var(--c-line)}" +
  ".wgc-chips{display:flex;flex-wrap:wrap;gap:8px;padding:2px 0 6px;animation:wgcIn .3s ease both}" +
  ".wgc-chip{border:1.5px solid var(--c-line);background:var(--c-bg);color:var(--c-ink);border-radius:999px;padding:8px 13px;font:600 13.5px/1.2 var(--body,'DM Sans',system-ui,sans-serif);cursor:pointer;text-align:left}" +
  ".wgc-chip:hover{border-color:var(--c-acc);color:var(--c-acc)}" +
  ".wgc-label{font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase;color:var(--c-muted);margin:6px 2px 0}" +
  ".wgc-typing{align-self:flex-start;background:var(--c-soft);border-radius:18px;border-bottom-left-radius:6px;padding:13px 16px;display:flex;gap:5px}" +
  ".wgc-typing i{width:7px;height:7px;border-radius:50%;background:var(--c-muted);opacity:.5;animation:wgcDot 1s infinite ease-in-out}" +
  ".wgc-typing i:nth-child(2){animation-delay:.15s}.wgc-typing i:nth-child(3){animation-delay:.3s}" +
  ".wgc-form{display:flex;gap:8px;padding:12px;border-top:1px solid var(--c-line);background:var(--c-bg);flex:none}" +
  ".wgc-input{flex:1;min-width:0;height:46px;border-radius:14px;border:1.5px solid var(--c-line);background:var(--c-bg);color:var(--c-ink);padding:0 14px;font:500 15px var(--body,'DM Sans',system-ui,sans-serif)}" +
  ".wgc-input:focus{outline:none;border-color:var(--c-acc)}" +
  ".wgc-send{width:46px;height:46px;border-radius:14px;border:0;background:var(--c-acc);color:var(--c-acc-ink);cursor:pointer;display:grid;place-items:center;flex:none}" +
  ".wgc-send:disabled{opacity:.45;cursor:default}" +
  ".wgc-foot{font-size:11.5px;color:var(--c-muted);text-align:center;padding:0 12px 10px;background:var(--c-bg);flex:none}" +
  "@keyframes wgcIn{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:none}}" +
  "@keyframes wgcPop{from{opacity:0;transform:translateY(12px) scale(.96)}to{opacity:1;transform:none}}" +
  "@keyframes wgcDot{0%,80%,100%{transform:translateY(0);opacity:.4}40%{transform:translateY(-4px);opacity:1}}" +
  "@media (max-width:560px){.wgc-panel{right:0;left:0;bottom:0;top:0;width:auto;height:auto;border-radius:0;border:0;padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}.wgc-launch{right:16px;bottom:calc(16px + env(safe-area-inset-bottom,0px))}.wgc-launch .txt{display:none}.wgc-launch{padding:0 12px}.wgc-launch .dot{left:34px}.wgc-hint{right:16px;bottom:calc(84px + env(safe-area-inset-bottom,0px))}}" +
  "@media (prefers-reduced-motion:reduce){.wgc *{animation:none!important;transition:none!important}.wgc-body{scroll-behavior:auto}}";
  var st = document.createElement("style"); st.textContent = css; document.head.appendChild(st);

  /* ---------- DOM ---------- */
  var ICON_CHAT = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#1d1400" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/><path d="M8.5 11h.01M12 11h.01M15.5 11h.01"/></svg>';
  var ICON_X = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg>';
  var ICON_SEND = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h13M13 6l6 6-6 6"/></svg>';
  var ICON_WA = '<svg width="16" height="16" viewBox="0 0 32 32" aria-hidden="true"><path fill="#fff" d="M16 3C9 3 3.3 8.6 3.3 15.6c0 2.3.6 4.5 1.8 6.4L3 29l7.2-1.9c1.8 1 3.8 1.5 5.8 1.5 7 0 12.7-5.6 12.7-12.6S23 3 16 3zm0 23.1c-1.8 0-3.6-.5-5.2-1.4l-.4-.2-4.3 1.1 1.2-4.2-.3-.4c-1-1.6-1.5-3.5-1.5-5.4C5.5 10 10.2 5.3 16 5.3S26.5 10 26.5 15.6 21.8 26.1 16 26.1z"/></svg>';

  var root = document.createElement("div"); root.className = "wgc";
  root.innerHTML =
    '<button class="wgc-launch" type="button" aria-haspopup="dialog" aria-expanded="false" aria-controls="wgcPanel"><span class="ic">' + ICON_CHAT + '</span><span class="txt">Ask a question</span><span class="dot" hidden></span></button>' +
    '<div class="wgc-panel" id="wgcPanel" role="dialog" aria-modal="false" aria-labelledby="wgcTitle" hidden>' +
      '<div class="wgc-head"><div class="wgc-logo" aria-hidden="true"><i style="background:#f2a900"></i><i style="background:#3fc79f"></i><i style="background:#3fc79f"></i><i style="background:#fff"></i></div>' +
        '<div class="wgc-title"><b id="wgcTitle">Widgetry Assistant</b><span>Answers in seconds</span></div>' +
        '<button class="wgc-close" type="button" aria-label="Close chat">' + ICON_X + '</button></div>' +
      '<div class="wgc-body" aria-live="polite"></div>' +
      '<form class="wgc-form" autocomplete="off"><label for="wgcInput" style="position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)">Type your question</label>' +
        '<input class="wgc-input" id="wgcInput" maxlength="300" placeholder="Type your question…"><button class="wgc-send" type="submit" aria-label="Send" disabled>' + ICON_SEND + '</button></form>' +
      '<div class="wgc-foot">Automatic answers · For anything else, chat with us on WhatsApp</div>' +
    '</div>';
  document.body.appendChild(root);

  var launch = root.querySelector(".wgc-launch"), panel = root.querySelector(".wgc-panel"),
      body = root.querySelector(".wgc-body"), form = root.querySelector(".wgc-form"),
      input = root.querySelector(".wgc-input"), send = root.querySelector(".wgc-send"),
      dot = root.querySelector(".dot"), hint = null, started = false, busy = false;
  var reduce = window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;
  var isPhone = function () { return window.matchMedia && matchMedia("(max-width:560px)").matches; };
  var store = { get: function (k) { try { return sessionStorage.getItem(k); } catch (e) { return null; } },
                set: function (k, v) { try { sessionStorage.setItem(k, v); } catch (e) {} } };

  function el(tag, cls, html) { var e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; }
  function esc(s) { var d = document.createElement("div"); d.textContent = s; return d.innerHTML; }
  function scrollDown() { body.scrollTop = body.scrollHeight; }
  function waLink(text) { return WA ? "https://wa.me/" + WA + "?text=" + encodeURIComponent(text) : HOME + "contact.html"; }

  function action(a) {
    var label = a[0], type = a[1], target = a[2];
    if (type === "wa") {
      var w = el("a", "wgc-act wa", ICON_WA + "<span>" + esc(label) + "</span>");
      w.href = waLink(target); w.target = "_blank"; w.rel = "noopener"; return w;
    }
    if (type === "link") {
      var l = el("a", "wgc-act alt", esc(label));
      l.href = HOME + target; if (/\.pdf$/.test(target)) l.target = "_blank"; return l;
    }
    var b = el("button", "wgc-act", esc(label)); b.type = "button";
    b.onclick = function () {
      var t = document.getElementById(target);
      if (t && t.hidden && target === "nextBatch") t = document.getElementById("fees");
      if (!t) { location.href = HOME + "#" + target; return; }
      if (isPhone()) close();
      t.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" });
    };
    return b;
  }

  function botSay(html, acts, chips, chipLabel) {
    var m = el("div", "wgc-msg bot", html);
    if (acts && acts.length) { var row = el("div", "wgc-acts"); acts.forEach(function (a) { row.appendChild(action(a)); }); m.appendChild(row); }
    body.appendChild(m);
    if (chips && chips.length) {
      if (chipLabel) body.appendChild(el("div", "wgc-label", chipLabel));
      var c = el("div", "wgc-chips");
      chips.forEach(function (id) {
        var it = BY[id]; if (!it) return;
        var b = el("button", "wgc-chip", esc(it.q)); b.type = "button";
        b.onclick = function () { ask(it.q, it); };
        c.appendChild(b);
      });
      body.appendChild(c);
    }
    scrollDown();
  }

  function respond(text, forced) {
    var it = forced || match(text);
    var typing = el("div", "wgc-typing", "<i></i><i></i><i></i>");
    typing.setAttribute("aria-label", "Assistant is typing");
    body.appendChild(typing); scrollDown();
    busy = true;
    setTimeout(function () {
      typing.remove(); busy = false;
      if (it) {
        botSay(esc(it.a), it.act, it.rel, "Related");
      } else {
        botSay("I don't have an answer for that yet. Ask us on WhatsApp and we'll reply quickly.",
          [["Ask on WhatsApp", "wa", "Hi! I have a question about " + COURSE + ": " + text]],
          ["fee", "batch", "beginner", "build"], "Popular questions");
      }
      input.focus({ preventScroll: true });
    }, reduce ? 150 : 550 + Math.min(500, ((it && it.a.length) || 60) * 2));
  }

  function ask(text, forced) {
    if (busy) return;
    text = String(text).trim(); if (!text) return;
    // Remove old chip rows so only the latest suggestions stay clickable
    Array.prototype.forEach.call(body.querySelectorAll(".wgc-chips,.wgc-label"), function (n) { n.remove(); });
    body.appendChild(el("div", "wgc-msg me", esc(text))); scrollDown();
    respond(text, forced);
  }

  function start() {
    if (started) return; started = true;
    botSay("Hi! I'm the Widgetry Assistant. Ask me anything about <b>" + COURSE + "</b>, or pick a question below.",
      null, STARTERS, "Popular questions");
  }
  function open() {
    if (hint) { hint.remove(); hint = null; }
    dot.hidden = true; store.set("wgc_seen", "1");
    panel.hidden = false; launch.setAttribute("aria-expanded", "true");
    start();
    setTimeout(function () { if (!isPhone()) input.focus({ preventScroll: true }); scrollDown(); }, 50);
  }
  function close() { panel.hidden = true; launch.setAttribute("aria-expanded", "false"); launch.focus({ preventScroll: true }); }

  launch.addEventListener("click", function () { panel.hidden ? open() : close(); });
  root.querySelector(".wgc-close").addEventListener("click", close);
  document.addEventListener("keydown", function (e) { if (e.key === "Escape" && !panel.hidden) close(); });
  input.addEventListener("input", function () { send.disabled = !input.value.trim(); });
  form.addEventListener("submit", function (e) { e.preventDefault(); var v = input.value; input.value = ""; send.disabled = true; ask(v); });

  // A gentle nudge once per visit, after the visitor has spent a little time on the page
  if (!store.get("wgc_seen")) {
    setTimeout(function () {
      if (!panel.hidden || store.get("wgc_seen")) return;
      dot.hidden = false;
      hint = el("div", "wgc-hint", "<b>Have a question?</b>Fees, batches, what you'll build. Ask here.<button class=\"x\" type=\"button\" aria-label=\"Dismiss\">×</button>");
      hint.setAttribute("role", "button"); hint.tabIndex = 0;
      hint.onclick = function (e) { if (e.target.classList.contains("x")) { hint.remove(); hint = null; store.set("wgc_seen", "1"); return; } open(); };
      root.appendChild(hint);
    }, 12000);
  }

  // Let other buttons on the page open the chat: <a href="#ask">…</a>
  document.addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest('a[href="#ask"]');
    if (a) { e.preventDefault(); open(); }
  });
})();
