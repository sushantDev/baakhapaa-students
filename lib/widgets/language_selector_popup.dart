import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:baakhapaa/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/language_provider.dart';

class LanguageSelectorPopup extends StatelessWidget {
  const LanguageSelectorPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)?.selectLanguage ?? 'Select Language',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: languageProvider.supportedLocales.length,
                itemBuilder: (context, index) {
                  final locale = languageProvider.supportedLocales[index];
                  final languageName =
                      languageProvider.languageNames[locale.languageCode] ??
                          locale.languageCode;
                  final isSelected =
                      languageProvider.currentLocale.languageCode ==
                          locale.languageCode;

                  return ListTile(
                    leading: Icon(Icons.language,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey),
                    title: Text(languageName),
                    trailing: isSelected
                        ? Icon(Icons.check,
                            color: Theme.of(context).primaryColor)
                        : null,
                    onTap: () async {
                      await languageProvider
                          .changeLanguage(locale.languageCode);

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                          'selectedLanguage', locale.languageCode);

                      Navigator.of(context).pop(); // close popup
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
