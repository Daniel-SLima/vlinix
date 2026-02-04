// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Vlinix Dashboard';

  @override
  String get menuOverview => 'Visão Geral';

  @override
  String get menuAgenda => 'Agenda';

  @override
  String get menuClients => 'Clientes';

  @override
  String get menuVehicles => 'Veículos';

  @override
  String get menuServices => 'Serviços';

  @override
  String get menuFinance => 'Financeiro';

  @override
  String get menuLogout => 'Sair';

  @override
  String get dashboardClients => 'Clientes';

  @override
  String get dashboardVehicles => 'Veículos';

  @override
  String get dashboardToday => 'Hoje';

  @override
  String get agendaToday => 'Agenda de Hoje';

  @override
  String get agendaUpcoming => 'Próximos Agendamentos';

  @override
  String get agendaEmptyToday => 'Tudo livre por hoje!';

  @override
  String get agendaEmptyUpcoming => 'Sem agendamentos futuros.';

  @override
  String get btnNew => 'Novo';

  @override
  String get btnSave => 'Salvar';

  @override
  String get btnSchedule => 'Agendar';

  @override
  String get btnUpdate => 'Salvar Alterações';

  @override
  String get btnCancel => 'Cancelar';

  @override
  String get btnDelete => 'Excluir';

  @override
  String get labelClient => 'Cliente';

  @override
  String get labelVehicle => 'Veículo';

  @override
  String get labelService => 'Serviço';

  @override
  String get labelName => 'Nome Completo';

  @override
  String get labelPhone => 'Telefone';

  @override
  String get labelEmail => 'Email';

  @override
  String get labelModel => 'Modelo';

  @override
  String get labelPlate => 'Placa';

  @override
  String get labelColor => 'Cor';

  @override
  String get labelOwner => 'Dono';

  @override
  String get statusPending => 'Pendente';

  @override
  String get statusDone => 'Concluído';

  @override
  String get dialogPaymentTitle => 'Forma de Pagamento';

  @override
  String get paymentCash => 'Dinheiro';

  @override
  String get paymentCard => 'Cartão';

  @override
  String get paymentPlan => 'Plano Mensal';

  @override
  String get filterAll => 'Todos';

  @override
  String get financeTitle => 'Controle Financeiro';

  @override
  String get financeTotal => 'Faturamento Total';

  @override
  String get financeEmpty => 'Nenhum serviço concluído neste mês.';

  @override
  String get titleManageClients => 'Gerenciar Clientes';

  @override
  String get titleAllVehicles => 'Todos os Veículos';

  @override
  String get msgNoClients => 'Nenhum cliente cadastrado.';

  @override
  String get msgNoVehicles => 'Nenhum veículo cadastrado.';

  @override
  String get msgClientCreated => 'Cliente criado!';

  @override
  String get msgClientUpdated => 'Cliente atualizado!';

  @override
  String get msgClientDeleted => 'Cliente excluído!';

  @override
  String get msgGoogleUpdated => 'Google Agenda Atualizada!';

  @override
  String get msgGoogleDeleted => 'Removido do Google Agenda!';

  @override
  String get msgErrorDeleteClient =>
      'Erro: Não é possível apagar cliente com agendamentos!';

  @override
  String get msgErrorDeleteVehicle => 'Erro: Carro possui agendamentos!';

  @override
  String get titleNewClient => 'Novo Cliente';

  @override
  String get titleEditClient => 'Editar Cliente';

  @override
  String get titleEditVehicle => 'Editar Veículo';

  @override
  String get dialogDeleteTitle => 'Excluir?';

  @override
  String get dialogDeleteContent => 'Isso apagará o registro permanentemente.';
}
