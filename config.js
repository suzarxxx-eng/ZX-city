/*
  إعدادات الموقع
  ---------------
  1) بعد ما تسوي مشروع Firebase، الصق إعدادات تطبيق الويب بدل null تحت.
  2) اكتب إيميل صاحب المطعم (اللي تسجل بيه دخول الموظفين) حتى الأرباح والمصاريف تفتح إله بس.
  إذا firebase بقت null، الموقع يشتغل بـ"وضع المعاينة": البيانات تنحفظ بنفس المتصفح بس.
*/
window.QARMASHA_CONFIG = {
  firebase: null,
  /* مثال:
  firebase: {
    apiKey: "AIza...",
    authDomain: "qarmasha.firebaseapp.com",
    projectId: "qarmasha",
    storageBucket: "qarmasha.appspot.com",
    messagingSenderId: "1234567890",
    appId: "1:1234567890:web:abcdef"
  },
  */
  ownerEmail: ""
};
