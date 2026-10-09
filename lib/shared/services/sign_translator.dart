import '../../data/models/fsl_sign_model.dart';
import '../../data/models/category_model.dart';
import 'app_settings.dart';

class SignTranslator {
  final _settings = AppSettings();

  bool get isEnglish => _settings.language.value == 'English';

  String signName(FslSignModel sign) {
    return isEnglish && sign.signNameEn != null && sign.signNameEn!.isNotEmpty
        ? sign.signNameEn!
        : sign.signName;
  }

  String signDescription(FslSignModel sign) {
    return isEnglish && sign.descriptionEn != null && sign.descriptionEn!.isNotEmpty
        ? sign.descriptionEn!
        : (sign.description ?? '');
  }

  String categoryName(CategoryModel cat) {
    return isEnglish && cat.categoryNameEn != null && cat.categoryNameEn!.isNotEmpty
        ? cat.categoryNameEn!
        : cat.categoryName;
  }

  String categoryNameFromString(String filipinoName, String englishName) {
    return isEnglish ? englishName : filipinoName;
  }
}
