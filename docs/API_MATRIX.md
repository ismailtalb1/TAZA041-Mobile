# مطابقة الشاشات وواجهات API

| المجال | واجهات Laravel المستخدمة |
|---|---|
| بيانات المطعم | `GET /public/restaurant`، `GET /public/restaurant/images` |
| المنيو والعروض | `GET /public/products`، `GET /public/offers`، `GET /public/pricing` |
| الحساب | `POST /customer/auth/login`، `register`، `forgot-password`، `reset-password`، `logout` |
| الملف الشخصي | `GET/PUT /customer/profile`، `POST /customer/avatar` |
| الطلبات | `GET/POST /customer/orders`، `GET /customer/orders/{id}`، `DELETE /customer/orders/{id}` |
| الدفع | `POST /customer/orders/{id}/pay` |
| التوصيل | `GET /public/delivery/quote`، وإحداثيات الطلب ضمن إنشاء الطلب |
| الحجوزات | `GET /public/reservations/table/{number}/availability`، وبيانات الحجز ضمن إنشاء الطلب |
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
- العناوين السريعة (البيت والعمل وعنوان آخر) تحفظ محليًا على الجهاز، وتُفحص إحداثياتها عبر `delivery/quote` قبل استخدامها.
