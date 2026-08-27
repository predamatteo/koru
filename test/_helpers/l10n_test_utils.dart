import 'package:flutter/widgets.dart';
import 'package:koru/l10n/generated/app_localizations.dart';

/// Le traduzioni, fuori da un albero di widget.
///
/// `AppLocalizations.of(context)` ha bisogno di un `Localizations` sopra di sé;
/// queste istanze no, e servono ai test che verificano le estensioni di
/// `presentation/l10n/model_labels.dart` — cioè funzioni pure che prendono le
/// stringhe come parametro proprio per poter essere testate senza montare
/// niente.
final AppLocalizations enL10n = lookupAppLocalizations(const Locale('en'));
final AppLocalizations itL10n = lookupAppLocalizations(const Locale('it'));
