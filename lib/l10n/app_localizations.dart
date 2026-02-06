import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In pt, this message translates to:
  /// **'Vlinix Dashboard'**
  String get appTitle;

  /// No description provided for @menuOverview.
  ///
  /// In pt, this message translates to:
  /// **'Visão Geral'**
  String get menuOverview;

  /// No description provided for @menuAgenda.
  ///
  /// In pt, this message translates to:
  /// **'Agenda'**
  String get menuAgenda;

  /// No description provided for @menuClients.
  ///
  /// In pt, this message translates to:
  /// **'Clientes'**
  String get menuClients;

  /// No description provided for @menuVehicles.
  ///
  /// In pt, this message translates to:
  /// **'Veículos'**
  String get menuVehicles;

  /// No description provided for @menuServices.
  ///
  /// In pt, this message translates to:
  /// **'Serviços'**
  String get menuServices;

  /// No description provided for @menuFinance.
  ///
  /// In pt, this message translates to:
  /// **'Financeiro'**
  String get menuFinance;

  /// No description provided for @menuLogout.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get menuLogout;

  /// No description provided for @dashboardClients.
  ///
  /// In pt, this message translates to:
  /// **'Clientes'**
  String get dashboardClients;

  /// No description provided for @dashboardVehicles.
  ///
  /// In pt, this message translates to:
  /// **'Veículos'**
  String get dashboardVehicles;

  /// No description provided for @dashboardToday.
  ///
  /// In pt, this message translates to:
  /// **'Hoje'**
  String get dashboardToday;

  /// No description provided for @agendaToday.
  ///
  /// In pt, this message translates to:
  /// **'Agenda de Hoje'**
  String get agendaToday;

  /// No description provided for @agendaUpcoming.
  ///
  /// In pt, this message translates to:
  /// **'Próximos Agendamentos'**
  String get agendaUpcoming;

  /// No description provided for @agendaEmptyToday.
  ///
  /// In pt, this message translates to:
  /// **'Tudo livre por hoje!'**
  String get agendaEmptyToday;

  /// No description provided for @agendaEmptyUpcoming.
  ///
  /// In pt, this message translates to:
  /// **'Sem agendamentos futuros.'**
  String get agendaEmptyUpcoming;

  /// No description provided for @btnNew.
  ///
  /// In pt, this message translates to:
  /// **'Novo'**
  String get btnNew;

  /// No description provided for @btnSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get btnSave;

  /// No description provided for @btnSchedule.
  ///
  /// In pt, this message translates to:
  /// **'Agendar'**
  String get btnSchedule;

  /// No description provided for @btnUpdate.
  ///
  /// In pt, this message translates to:
  /// **'Salvar Alterações'**
  String get btnUpdate;

  /// No description provided for @btnCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get btnCancel;

  /// No description provided for @btnDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get btnDelete;

  /// No description provided for @labelClient.
  ///
  /// In pt, this message translates to:
  /// **'Cliente'**
  String get labelClient;

  /// No description provided for @labelVehicle.
  ///
  /// In pt, this message translates to:
  /// **'Veículo'**
  String get labelVehicle;

  /// No description provided for @labelService.
  ///
  /// In pt, this message translates to:
  /// **'Serviço'**
  String get labelService;

  /// No description provided for @labelName.
  ///
  /// In pt, this message translates to:
  /// **'Nome Completo'**
  String get labelName;

  /// No description provided for @labelPhone.
  ///
  /// In pt, this message translates to:
  /// **'Telefone'**
  String get labelPhone;

  /// No description provided for @labelEmail.
  ///
  /// In pt, this message translates to:
  /// **'Email'**
  String get labelEmail;

  /// No description provided for @labelModel.
  ///
  /// In pt, this message translates to:
  /// **'Modelo'**
  String get labelModel;

  /// No description provided for @labelPlate.
  ///
  /// In pt, this message translates to:
  /// **'Placa'**
  String get labelPlate;

  /// No description provided for @labelColor.
  ///
  /// In pt, this message translates to:
  /// **'Cor'**
  String get labelColor;

  /// No description provided for @labelOwner.
  ///
  /// In pt, this message translates to:
  /// **'Dono'**
  String get labelOwner;

  /// No description provided for @statusPending.
  ///
  /// In pt, this message translates to:
  /// **'Pendente'**
  String get statusPending;

  /// No description provided for @statusDone.
  ///
  /// In pt, this message translates to:
  /// **'Concluído'**
  String get statusDone;

  /// No description provided for @dialogPaymentTitle.
  ///
  /// In pt, this message translates to:
  /// **'Forma de Pagamento'**
  String get dialogPaymentTitle;

  /// No description provided for @paymentCash.
  ///
  /// In pt, this message translates to:
  /// **'Dinheiro'**
  String get paymentCash;

  /// No description provided for @paymentCard.
  ///
  /// In pt, this message translates to:
  /// **'Cartão'**
  String get paymentCard;

  /// No description provided for @paymentPlan.
  ///
  /// In pt, this message translates to:
  /// **'Plano Mensal'**
  String get paymentPlan;

  /// No description provided for @filterAll.
  ///
  /// In pt, this message translates to:
  /// **'Todos'**
  String get filterAll;

  /// No description provided for @financeTitle.
  ///
  /// In pt, this message translates to:
  /// **'Controle Financeiro'**
  String get financeTitle;

  /// No description provided for @financeTotal.
  ///
  /// In pt, this message translates to:
  /// **'Faturamento Total'**
  String get financeTotal;

  /// No description provided for @financeEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum serviço concluído neste mês.'**
  String get financeEmpty;

  /// No description provided for @titleManageClients.
  ///
  /// In pt, this message translates to:
  /// **'Gerenciar Clientes'**
  String get titleManageClients;

  /// No description provided for @titleAllVehicles.
  ///
  /// In pt, this message translates to:
  /// **'Todos os Veículos'**
  String get titleAllVehicles;

  /// No description provided for @msgNoClients.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum cliente cadastrado.'**
  String get msgNoClients;

  /// No description provided for @msgNoVehicles.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum veículo cadastrado.'**
  String get msgNoVehicles;

  /// No description provided for @msgClientCreated.
  ///
  /// In pt, this message translates to:
  /// **'Cliente criado!'**
  String get msgClientCreated;

  /// No description provided for @msgClientUpdated.
  ///
  /// In pt, this message translates to:
  /// **'Cliente atualizado!'**
  String get msgClientUpdated;

  /// No description provided for @msgClientDeleted.
  ///
  /// In pt, this message translates to:
  /// **'Cliente excluído!'**
  String get msgClientDeleted;

  /// No description provided for @msgGoogleUpdated.
  ///
  /// In pt, this message translates to:
  /// **'Google Agenda Atualizada!'**
  String get msgGoogleUpdated;

  /// No description provided for @msgGoogleDeleted.
  ///
  /// In pt, this message translates to:
  /// **'Removido do Google Agenda!'**
  String get msgGoogleDeleted;

  /// No description provided for @msgErrorDeleteClient.
  ///
  /// In pt, this message translates to:
  /// **'Erro: Não é possível apagar cliente com agendamentos!'**
  String get msgErrorDeleteClient;

  /// No description provided for @msgErrorDeleteVehicle.
  ///
  /// In pt, this message translates to:
  /// **'Erro: Carro possui agendamentos!'**
  String get msgErrorDeleteVehicle;

  /// No description provided for @titleNewClient.
  ///
  /// In pt, this message translates to:
  /// **'Novo Cliente'**
  String get titleNewClient;

  /// No description provided for @titleEditClient.
  ///
  /// In pt, this message translates to:
  /// **'Editar Cliente'**
  String get titleEditClient;

  /// No description provided for @titleEditVehicle.
  ///
  /// In pt, this message translates to:
  /// **'Editar Veículo'**
  String get titleEditVehicle;

  /// No description provided for @dialogDeleteTitle.
  ///
  /// In pt, this message translates to:
  /// **'Excluir?'**
  String get dialogDeleteTitle;

  /// No description provided for @dialogDeleteContent.
  ///
  /// In pt, this message translates to:
  /// **'Isso apagará o registro permanentemente.'**
  String get dialogDeleteContent;

  /// No description provided for @labelSelectServices.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar Serviços'**
  String get labelSelectServices;

  /// No description provided for @labelTotal.
  ///
  /// In pt, this message translates to:
  /// **'Total Estimado'**
  String get labelTotal;

  /// No description provided for @msgSelectService.
  ///
  /// In pt, this message translates to:
  /// **'Selecione pelo menos um serviço!'**
  String get msgSelectService;

  /// No description provided for @msgSelectClientVehicle.
  ///
  /// In pt, this message translates to:
  /// **'Selecione Cliente e Veículo!'**
  String get msgSelectClientVehicle;

  /// No description provided for @tooltipEditProfile.
  ///
  /// In pt, this message translates to:
  /// **'Editar Perfil'**
  String get tooltipEditProfile;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
