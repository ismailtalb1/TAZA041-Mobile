# مطابقة الشاشات وواجهات API

| المجال | واجهات Laravel المستخدمة |
|---|---|
| بيانات المطعم | `GET /public/restaurant`، `GET /public/restaurant/images`، والمزامنة الذكية عبر `GET /public/live-data?since={revision}` |
| المنيو والعروض | `GET /public/products`، `GET /public/offers`، `GET /public/pricing` |
| الحساب | `POST /customer/auth/login`، `register`، `forgot-password`، `reset-password`، `logout` |
| الملف الشخصي | `GET/PUT /customer/profile`، `POST /customer/avatar` |
| العناوين المحفوظة | `GET/PUT /customer/saved-addresses`، `PUT/DELETE /customer/saved-addresses/{type}` |
| الطلبات | `GET/POST /customer/orders`، `GET /customer/orders/{id}`، `DELETE /customer/orders/{id}` |
| إعادة الطلب | `GET /customer/orders/{id}` ثم مطابقة العناصر المتاحة مع الكتالوج الحي قبل بناء السلة |
| بلاغ عدم التوفر | `POST /customer/products/{id}/report-unavailable` |
| الدفع | `POST /customer/orders/{id}/pay` |
| التوصيل | `GET /public/delivery/quote` للمسافة والمدة والتكلفة و`route.geometry`، وإحداثيات الطلب ضمن إنشاء الطلب |
| الحجوزات | `GET /public/reservations/tables`، `GET /public/reservations/table/{number}/availability`، وبيانات الحجز ضمن إنشاء الطلب |
| الإشعارات | `GET /customer/notifications`، `PUT /{id}/read`، `PUT /read-all` |
| التقييم | `POST /customer/delivery/{id}/rate`، `POST /customer/orders/{orderId}/products/{productId}/rate` |
| المساعد | `POST /public/ai/chat` أو `POST /customer/ai/chat` |

## قواعد التنفيذ

- جميع الطلبات المحمية ترسل `Bearer token` من التخزين الآمن.
- السلة وتفضيلات اللغة والثيم ومعرّف الطلب غير المدفوع تحفظ محليًا لمنع إنشاء طلب مكرر عند إعادة محاولة الدفع.
- بيانات المنتجات والأسعار والتوفر وتكلفة التوصيل وحالة الطاولة تأتي من الـBackend وليست بيانات ثابتة.
- التقييم لا يظهر إلا بعد أن يسمح به الخادم، وإلغاء الطلب متاح للحالة المعلقة فقط.
- حالات الخطأ والمهلة وانتهاء الجلسة تظهر للمستخدم وتُزامن الحالة من الخادم بعد العمليات المؤثرة في قاعدة البيانات.
- محتوى الرئيسية وصفحة «عن المطعم» يأتي من `website_content` الذي يديره مدير التواصل.
- العناوين السريعة (البيت والعمل وعنوان آخر) تُحفظ في Laravel وتُزامن مع كاش الجهاز للعمل بسلاسة عند ضعف الاتصال، وتُفحص إحداثياتها عبر `delivery/quote` قبل استخدامها.
- يرسم التطبيق الـPolyline القادم من Laravel بصيغة `[longitude, latitude]`، ويقرأ المسار المخزن نفسه من تفاصيل الطلب كي تتطابق خريطة الهاتف مع الويب والسائق والإدارة.
- عند تغيير نقطة الخريطة يُلغى عرض السعر والمسار السابقان فورًا، ولا يسمح بالدفع قبل اعتماد Quote جديد للموقع الحالي.
- عند بقاء التطبيق في الواجهة تُفحص مراجعة البيانات العامة والطلبات والإشعارات كل 12 ثانية دون تداخل الطلبات؛ وتتوقف الدورة في الخلفية وتعمل فور استئناف التطبيق.
- طلبات `GET` المتطابقة والمتزامنة تشترك في Future واحد لمنع ازدواج الشبكة، بينما تبقى عمليات الكتابة منفصلة ولا يعاد إرسالها تلقائيًا.
