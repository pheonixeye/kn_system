import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart' show DateFormat;

class PostOperativeMedicalReport extends Equatable {
  final String patientName;
  final DateTime operativeDate;
  final String? nationalId;
  final String header;
  final String firstLeftFooter;
  final String secondLeftFooter;
  final String thirdLeftFooter;

  const PostOperativeMedicalReport({
    required this.patientName,
    required this.operativeDate,
    required this.nationalId,
    this.header = 'تقرير طبي',
    this.firstLeftFooter = 'و لكم جزيل الشكر',
    this.secondLeftFooter = 'د / خالد نبيل سعد',
    this.thirdLeftFooter = 'اخصائى الجراحة و التجميل و تنسيق القوام',
  });

  @override
  List<Object?> get props => [
    patientName,
    operativeDate,
    nationalId,
    header,
    firstLeftFooter,
    secondLeftFooter,
    thirdLeftFooter,
  ];

  String get medicalReportBodyPostOperative {
    final formattedDate = DateFormat('dd/MM/yyyy', 'ar').format(operativeDate);
    final dateToDay = DateFormat('EEEE', 'ar').format(operativeDate);
    return """
في تمام اليوم $formattedDate الموافق $dateToDay
حضر الينا أ/$patientName
${(nationalId != null && nationalId!.isNotEmpty) ? 'رقم قومي: $nationalId' : ''}
الذى يعانى من صلع وراثى.
تم عمل اللازم و خروج المريض تحسن و مطلوب الراحه لمده اسبوع (سبعه ايام) من تاريخ الخروج و ذلك للتحسن و المتابعه لحين الاستشفاء
تاريخ الخروج : $formattedDate
    """;
  }
}
