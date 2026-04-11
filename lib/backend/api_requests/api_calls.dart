import 'dart:convert';
import 'dart:typed_data';
import '../schema/structs/index.dart';

import 'package:flutter/foundation.dart';

import '/flutter_flow/flutter_flow_util.dart';
import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

const _kPrivateApiFunctionName = 'ffPrivateApiCall';

/// Start API ClickPalm Group Code

class APIClickPalmGroup {
  static String getBaseUrl() => 'https://api.clickpalm.com';
  static Map<String, String> headers = {};
  static ActivitiesGETCall activitiesGETCall = ActivitiesGETCall();
  static ActivitiesPOSTCall activitiesPOSTCall = ActivitiesPOSTCall();
  static ActivitiesidGETCall activitiesidGETCall = ActivitiesidGETCall();
  static ActivitiesidPUTCall activitiesidPUTCall = ActivitiesidPUTCall();
  static ActivitiesidDELETECall activitiesidDELETECall =
      ActivitiesidDELETECall();
  static ActivitiesFiltersGETCall activitiesFiltersGETCall =
      ActivitiesFiltersGETCall();
  static ActivitiesStatusGETCall activitiesStatusGETCall =
      ActivitiesStatusGETCall();
  static ActivitiesStatusPOSTCall activitiesStatusPOSTCall =
      ActivitiesStatusPOSTCall();
  static ActivitiesStatusidGETCall activitiesStatusidGETCall =
      ActivitiesStatusidGETCall();
  static ActivitiesStatusidPUTCall activitiesStatusidPUTCall =
      ActivitiesStatusidPUTCall();
  static ActivitiesStatusidDELETECall activitiesStatusidDELETECall =
      ActivitiesStatusidDELETECall();
  static ActivitiesStatusFiltersGETCall activitiesStatusFiltersGETCall =
      ActivitiesStatusFiltersGETCall();
  static ArchivesGETCall archivesGETCall = ArchivesGETCall();
  static ArchivesPOSTCall archivesPOSTCall = ArchivesPOSTCall();
  static ArchivesidGETCall archivesidGETCall = ArchivesidGETCall();
  static ArchivesidPUTCall archivesidPUTCall = ArchivesidPUTCall();
  static ArchivesidDELETECall archivesidDELETECall = ArchivesidDELETECall();
  static ArchivesFiltersGETCall archivesFiltersGETCall =
      ArchivesFiltersGETCall();
  static BrazalsGETCall brazalsGETCall = BrazalsGETCall();
  static BrazalsPOSTCall brazalsPOSTCall = BrazalsPOSTCall();
  static BrazalsidGETCall brazalsidGETCall = BrazalsidGETCall();
  static BrazalsidPUTCall brazalsidPUTCall = BrazalsidPUTCall();
  static BrazalsidDELETECall brazalsidDELETECall = BrazalsidDELETECall();
  static BrazalsFiltersGETCall brazalsFiltersGETCall = BrazalsFiltersGETCall();
  static CompaniesGETCall companiesGETCall = CompaniesGETCall();
  static CompaniesPOSTCall companiesPOSTCall = CompaniesPOSTCall();
  static CompaniesidGETCall companiesidGETCall = CompaniesidGETCall();
  static CompaniesidPUTCall companiesidPUTCall = CompaniesidPUTCall();
  static CompaniesidDELETECall companiesidDELETECall = CompaniesidDELETECall();
  static CompaniesFiltersGETCall companiesFiltersGETCall =
      CompaniesFiltersGETCall();
  static CyclesGETCall cyclesGETCall = CyclesGETCall();
  static CyclesPOSTCall cyclesPOSTCall = CyclesPOSTCall();
  static CyclesidGETCall cyclesidGETCall = CyclesidGETCall();
  static CyclesidPUTCall cyclesidPUTCall = CyclesidPUTCall();
  static CyclesidDELETECall cyclesidDELETECall = CyclesidDELETECall();
  static CyclesFiltersGETCall cyclesFiltersGETCall = CyclesFiltersGETCall();
  static DashboardsGetDashboardMainPOSTCall dashboardsGetDashboardMainPOSTCall =
      DashboardsGetDashboardMainPOSTCall();
  static DevicesGETCall devicesGETCall = DevicesGETCall();
  static DevicesPOSTCall devicesPOSTCall = DevicesPOSTCall();
  static DevicesidGETCall devicesidGETCall = DevicesidGETCall();
  static DevicesidPUTCall devicesidPUTCall = DevicesidPUTCall();
  static DevicesidDELETECall devicesidDELETECall = DevicesidDELETECall();
  static DevicesFiltersGETCall devicesFiltersGETCall = DevicesFiltersGETCall();
  static FlowersGETCall flowersGETCall = FlowersGETCall();
  static FlowersPOSTCall flowersPOSTCall = FlowersPOSTCall();
  static FlowersidGETCall flowersidGETCall = FlowersidGETCall();
  static FlowersidPUTCall flowersidPUTCall = FlowersidPUTCall();
  static FlowersidDELETECall flowersidDELETECall = FlowersidDELETECall();
  static FlowersFiltersGETCall flowersFiltersGETCall = FlowersFiltersGETCall();
  static GroupsMetricsGETCall groupsMetricsGETCall = GroupsMetricsGETCall();
  static GroupsMetricsPOSTCall groupsMetricsPOSTCall = GroupsMetricsPOSTCall();
  static GroupsMetricsidGETCall groupsMetricsidGETCall =
      GroupsMetricsidGETCall();
  static GroupsMetricsidPUTCall groupsMetricsidPUTCall =
      GroupsMetricsidPUTCall();
  static GroupsMetricsidDELETECall groupsMetricsidDELETECall =
      GroupsMetricsidDELETECall();
  static GroupsMetricsFiltersGETCall groupsMetricsFiltersGETCall =
      GroupsMetricsFiltersGETCall();
  static HeadquartersGETCall headquartersGETCall = HeadquartersGETCall();
  static HeadquartersPOSTCall headquartersPOSTCall = HeadquartersPOSTCall();
  static HeadquartersidGETCall headquartersidGETCall = HeadquartersidGETCall();
  static HeadquartersidPUTCall headquartersidPUTCall = HeadquartersidPUTCall();
  static HeadquartersidDELETECall headquartersidDELETECall =
      HeadquartersidDELETECall();
  static HeadquartersFiltersGETCall headquartersFiltersGETCall =
      HeadquartersFiltersGETCall();
  static HeadquartersWeightsGETCall headquartersWeightsGETCall =
      HeadquartersWeightsGETCall();
  static HeadquartersWeightsPOSTCall headquartersWeightsPOSTCall =
      HeadquartersWeightsPOSTCall();
  static HeadquartersWeightsidGETCall headquartersWeightsidGETCall =
      HeadquartersWeightsidGETCall();
  static HeadquartersWeightsidPUTCall headquartersWeightsidPUTCall =
      HeadquartersWeightsidPUTCall();
  static HeadquartersWeightsidDELETECall headquartersWeightsidDELETECall =
      HeadquartersWeightsidDELETECall();
  static HeadquartersWeightsFiltersGETCall headquartersWeightsFiltersGETCall =
      HeadquartersWeightsFiltersGETCall();
  static MetricsGETCall metricsGETCall = MetricsGETCall();
  static MetricsPOSTCall metricsPOSTCall = MetricsPOSTCall();
  static MetricsidGETCall metricsidGETCall = MetricsidGETCall();
  static MetricsidPUTCall metricsidPUTCall = MetricsidPUTCall();
  static MetricsidDELETECall metricsidDELETECall = MetricsidDELETECall();
  static MetricsFiltersGETCall metricsFiltersGETCall = MetricsFiltersGETCall();
  static MetricsFiltersPOSTCall metricsFiltersPOSTCall =
      MetricsFiltersPOSTCall();
  static MetricsFiltersidGETCall metricsFiltersidGETCall =
      MetricsFiltersidGETCall();
  static MetricsFiltersidPUTCall metricsFiltersidPUTCall =
      MetricsFiltersidPUTCall();
  static MetricsFiltersidDELETECall metricsFiltersidDELETECall =
      MetricsFiltersidDELETECall();
  static MetricsFiltersFiltersGETCall metricsFiltersFiltersGETCall =
      MetricsFiltersFiltersGETCall();
  static MetricsItemsGETCall metricsItemsGETCall = MetricsItemsGETCall();
  static MetricsItemsPOSTCall metricsItemsPOSTCall = MetricsItemsPOSTCall();
  static MetricsItemsidGETCall metricsItemsidGETCall = MetricsItemsidGETCall();
  static MetricsItemsidPUTCall metricsItemsidPUTCall = MetricsItemsidPUTCall();
  static MetricsItemsidDELETECall metricsItemsidDELETECall =
      MetricsItemsidDELETECall();
  static MetricsItemsFiltersGETCall metricsItemsFiltersGETCall =
      MetricsItemsFiltersGETCall();
  static PolinizationConfigurationGETCall polinizationConfigurationGETCall =
      PolinizationConfigurationGETCall();
  static PolinizationConfigurationPOSTCall polinizationConfigurationPOSTCall =
      PolinizationConfigurationPOSTCall();
  static PolinizationConfigurationidGETCall polinizationConfigurationidGETCall =
      PolinizationConfigurationidGETCall();
  static PolinizationConfigurationidPUTCall polinizationConfigurationidPUTCall =
      PolinizationConfigurationidPUTCall();
  static PolinizationConfigurationidDELETECall
      polinizationConfigurationidDELETECall =
      PolinizationConfigurationidDELETECall();
  static PolinizationConfigurationFiltersGETCall
      polinizationConfigurationFiltersGETCall =
      PolinizationConfigurationFiltersGETCall();
  static PolinizationConfigurationStatusGETCall
      polinizationConfigurationStatusGETCall =
      PolinizationConfigurationStatusGETCall();
  static PolinizationConfigurationStatusPOSTCall
      polinizationConfigurationStatusPOSTCall =
      PolinizationConfigurationStatusPOSTCall();
  static PolinizationConfigurationStatusidGETCall
      polinizationConfigurationStatusidGETCall =
      PolinizationConfigurationStatusidGETCall();
  static PolinizationConfigurationStatusidPUTCall
      polinizationConfigurationStatusidPUTCall =
      PolinizationConfigurationStatusidPUTCall();
  static PolinizationConfigurationStatusidDELETECall
      polinizationConfigurationStatusidDELETECall =
      PolinizationConfigurationStatusidDELETECall();
  static PolinizationConfigurationStatusFiltersGETCall
      polinizationConfigurationStatusFiltersGETCall =
      PolinizationConfigurationStatusFiltersGETCall();
  static PolinizationsFlowersGETCall polinizationsFlowersGETCall =
      PolinizationsFlowersGETCall();
  static PolinizationsFlowersPOSTCall polinizationsFlowersPOSTCall =
      PolinizationsFlowersPOSTCall();
  static PolinizationsFlowersidGETCall polinizationsFlowersidGETCall =
      PolinizationsFlowersidGETCall();
  static PolinizationsFlowersidPUTCall polinizationsFlowersidPUTCall =
      PolinizationsFlowersidPUTCall();
  static PolinizationsFlowersidDELETECall polinizationsFlowersidDELETECall =
      PolinizationsFlowersidDELETECall();
  static PolinizationsFlowersFiltersGETCall polinizationsFlowersFiltersGETCall =
      PolinizationsFlowersFiltersGETCall();
  static PricesProductsGETCall pricesProductsGETCall = PricesProductsGETCall();
  static PricesProductsPOSTCall pricesProductsPOSTCall =
      PricesProductsPOSTCall();
  static PricesProductsidGETCall pricesProductsidGETCall =
      PricesProductsidGETCall();
  static PricesProductsidPUTCall pricesProductsidPUTCall =
      PricesProductsidPUTCall();
  static PricesProductsidDELETECall pricesProductsidDELETECall =
      PricesProductsidDELETECall();
  static PricesProductsFiltersGETCall pricesProductsFiltersGETCall =
      PricesProductsFiltersGETCall();
  static ProductsGETCall productsGETCall = ProductsGETCall();
  static ProductsPOSTCall productsPOSTCall = ProductsPOSTCall();
  static ProductsidGETCall productsidGETCall = ProductsidGETCall();
  static ProductsidPUTCall productsidPUTCall = ProductsidPUTCall();
  static ProductsidDELETECall productsidDELETECall = ProductsidDELETECall();
  static ProductsFiltersGETCall productsFiltersGETCall =
      ProductsFiltersGETCall();
  static ReportsReportsDailysPOSTCall reportsReportsDailysPOSTCall =
      ReportsReportsDailysPOSTCall();
  static ReportsGETCall reportsGETCall = ReportsGETCall();
  static ReportsPOSTCall reportsPOSTCall = ReportsPOSTCall();
  static ReportsidGETCall reportsidGETCall = ReportsidGETCall();
  static ReportsidPUTCall reportsidPUTCall = ReportsidPUTCall();
  static ReportsidDELETECall reportsidDELETECall = ReportsidDELETECall();
  static ReportsFiltersGETCall reportsFiltersGETCall = ReportsFiltersGETCall();
  static StockProductsGETCall stockProductsGETCall = StockProductsGETCall();
  static StockProductsPOSTCall stockProductsPOSTCall = StockProductsPOSTCall();
  static StockProductsidGETCall stockProductsidGETCall =
      StockProductsidGETCall();
  static StockProductsidPUTCall stockProductsidPUTCall =
      StockProductsidPUTCall();
  static StockProductsidDELETECall stockProductsidDELETECall =
      StockProductsidDELETECall();
  static StockProductsFiltersGETCall stockProductsFiltersGETCall =
      StockProductsFiltersGETCall();
  static SyncTimesSyncFullPOSTCall syncTimesSyncFullPOSTCall =
      SyncTimesSyncFullPOSTCall();
  static SyncTimesSyncFlowersPOSTCall syncTimesSyncFlowersPOSTCall =
      SyncTimesSyncFlowersPOSTCall();
  static SyncTimesGETCall syncTimesGETCall = SyncTimesGETCall();
  static SyncTimesPOSTCall syncTimesPOSTCall = SyncTimesPOSTCall();
  static SyncVisitsAddCall syncVisitsAddCall = SyncVisitsAddCall();
  static SyncTimesidGETCall syncTimesidGETCall = SyncTimesidGETCall();
  static SyncTimesidPUTCall syncTimesidPUTCall = SyncTimesidPUTCall();
  static SyncTimesidDELETECall syncTimesidDELETECall = SyncTimesidDELETECall();
  static SyncTimesFiltersGETCall syncTimesFiltersGETCall =
      SyncTimesFiltersGETCall();
  static TasksGETCall tasksGETCall = TasksGETCall();
  static TasksPOSTCall tasksPOSTCall = TasksPOSTCall();
  static TasksidGETCall tasksidGETCall = TasksidGETCall();
  static TasksidPUTCall tasksidPUTCall = TasksidPUTCall();
  static TasksidDELETECall tasksidDELETECall = TasksidDELETECall();
  static TasksFiltersGETCall tasksFiltersGETCall = TasksFiltersGETCall();
  static UsersLoginPOSTCall usersLoginPOSTCall = UsersLoginPOSTCall();
  static UsersGETCall usersGETCall = UsersGETCall();
  static UsersPOSTCall usersPOSTCall = UsersPOSTCall();
  static UsersidGETCall usersidGETCall = UsersidGETCall();
  static UsersidPUTCall usersidPUTCall = UsersidPUTCall();
  static UsersidDELETECall usersidDELETECall = UsersidDELETECall();
  static UsersFiltersGETCall usersFiltersGETCall = UsersFiltersGETCall();
  static UsersbyoperidGETCall usersbyoperidGETCall = UsersbyoperidGETCall();
  static ValidateSupervisorGETCall validateSupervisorGETCall = ValidateSupervisorGETCall();
  static UsersCredentialsGETCall usersCredentialsGETCall =
      UsersCredentialsGETCall();
  static UsersCredentialsPOSTCall usersCredentialsPOSTCall =
      UsersCredentialsPOSTCall();
  static UsersCredentialsidGETCall usersCredentialsidGETCall =
      UsersCredentialsidGETCall();
  static UsersCredentialsidPUTCall usersCredentialsidPUTCall =
      UsersCredentialsidPUTCall();
  static UsersCredentialsidDELETECall usersCredentialsidDELETECall =
      UsersCredentialsidDELETECall();
  static UsersCredentialsFiltersGETCall usersCredentialsFiltersGETCall =
      UsersCredentialsFiltersGETCall();
  static UsersDevicesGETCall usersDevicesGETCall = UsersDevicesGETCall();
  static UsersDevicesPOSTCall usersDevicesPOSTCall = UsersDevicesPOSTCall();
  static UsersDevicesidGETCall usersDevicesidGETCall = UsersDevicesidGETCall();
  static UsersDevicesidPUTCall usersDevicesidPUTCall = UsersDevicesidPUTCall();
  static UsersDevicesidDELETECall usersDevicesidDELETECall =
      UsersDevicesidDELETECall();
  static UsersDevicesFiltersGETCall usersDevicesFiltersGETCall =
      UsersDevicesFiltersGETCall();
  static UsersPermissionsGETCall usersPermissionsGETCall =
      UsersPermissionsGETCall();
  static UsersPermissionsPOSTCall usersPermissionsPOSTCall =
      UsersPermissionsPOSTCall();
  static UsersPermissionsidGETCall usersPermissionsidGETCall =
      UsersPermissionsidGETCall();
  static UsersPermissionsidPUTCall usersPermissionsidPUTCall =
      UsersPermissionsidPUTCall();
  static UsersPermissionsidDELETECall usersPermissionsidDELETECall =
      UsersPermissionsidDELETECall();
  static UsersPermissionsFiltersGETCall usersPermissionsFiltersGETCall =
      UsersPermissionsFiltersGETCall();
  static VisitsGETCall visitsGETCall = VisitsGETCall();
  static VisitsPOSTCall visitsPOSTCall = VisitsPOSTCall();
  static VisitsidGETCall visitsidGETCall = VisitsidGETCall();
  static VisitsidPUTCall visitsidPUTCall = VisitsidPUTCall();
  static VisitsidDELETECall visitsidDELETECall = VisitsidDELETECall();
  static VisitsFiltersGETCall visitsFiltersGETCall = VisitsFiltersGETCall();
  static VisitsBulkGETCall visitsBulkGETCall = VisitsBulkGETCall();
  static VisitsBulkPOSTCall visitsBulkPOSTCall = VisitsBulkPOSTCall();
  static VisitsBulkidGETCall visitsBulkidGETCall = VisitsBulkidGETCall();
  static VisitsBulkidPUTCall visitsBulkidPUTCall = VisitsBulkidPUTCall();
  static VisitsBulkidDELETECall visitsBulkidDELETECall =
      VisitsBulkidDELETECall();
  static VisitsBulkFiltersGETCall visitsBulkFiltersGETCall =
      VisitsBulkFiltersGETCall();
  static VisitsPolinizationsStatusGETCall visitsPolinizationsStatusGETCall =
      VisitsPolinizationsStatusGETCall();
  static VisitsPolinizationsStatusPOSTCall visitsPolinizationsStatusPOSTCall =
      VisitsPolinizationsStatusPOSTCall();
  static VisitsPolinizationsStatusidGETCall visitsPolinizationsStatusidGETCall =
      VisitsPolinizationsStatusidGETCall();
  static VisitsPolinizationsStatusidPUTCall visitsPolinizationsStatusidPUTCall =
      VisitsPolinizationsStatusidPUTCall();
  static VisitsPolinizationsStatusidDELETECall
      visitsPolinizationsStatusidDELETECall =
      VisitsPolinizationsStatusidDELETECall();
  static VisitsPolinizationsStatusFiltersGETCall
      visitsPolinizationsStatusFiltersGETCall =
      VisitsPolinizationsStatusFiltersGETCall();
  static ZonesGETCall zonesGETCall = ZonesGETCall();
  static ZonesPOSTCall zonesPOSTCall = ZonesPOSTCall();
  static ZonesidGETCall zonesidGETCall = ZonesidGETCall();
  static ZonesidPUTCall zonesidPUTCall = ZonesidPUTCall();
  static ZonesidDELETECall zonesidDELETECall = ZonesidDELETECall();
  static ZonesFiltersGETCall zonesFiltersGETCall = ZonesFiltersGETCall();
}

class ActivitiesGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Activities GET',
      apiUrl: '${baseUrl}/Activities',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_activity": 123,
  "id_company": 123,
  "created_at": "example string",
  "name_activity": "example string",
  "group_activity": "example string",
  "unity": "example string",
  "cycle": 123,
  "efectivity": 123,
  "module_activity": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Activities POST',
      apiUrl: '${baseUrl}/Activities',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Activities/{id} GET',
      apiUrl: '${baseUrl}/Activities/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_activity": 123,
  "id_company": 123,
  "created_at": "example string",
  "name_activity": "example string",
  "group_activity": "example string",
  "unity": "example string",
  "cycle": 123,
  "efectivity": 123,
  "module_activity": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Activities/{id} PUT',
      apiUrl: '${baseUrl}/Activities/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Activities/{id} DELETE',
      apiUrl: '${baseUrl}/Activities/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Activities/filters GET',
      apiUrl: '${baseUrl}/Activities/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesStatusGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Activities_status GET',
      apiUrl: '${baseUrl}/Activities_status',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesStatusPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_activity_status": 123,
  "id_activity": 123,
  "status_name": "example string",
  "boton": 123,
  "factor": 123,
  "peso": 0,
  "color": "example string",
  "castigo": 123,
  "orden": 123,
  "status": "example string",
  "created_at": "example string",
  "modified_at": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Activities_status POST',
      apiUrl: '${baseUrl}/Activities_status',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesStatusidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Activities_status/{id} GET',
      apiUrl: '${baseUrl}/Activities_status/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesStatusidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_activity_status": 123,
  "id_activity": 123,
  "status_name": "example string",
  "boton": 123,
  "factor": 123,
  "peso": 0,
  "color": "example string",
  "castigo": 123,
  "orden": 123,
  "status": "example string",
  "created_at": "example string",
  "modified_at": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Activities_status/{id} PUT',
      apiUrl: '${baseUrl}/Activities_status/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesStatusidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Activities_status/{id} DELETE',
      apiUrl: '${baseUrl}/Activities_status/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ActivitiesStatusFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Activities_status/filters GET',
      apiUrl: '${baseUrl}/Activities_status/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ArchivesGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Archives GET',
      apiUrl: '${baseUrl}/Archives',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ArchivesPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_archive": 123,
  "id_company": 123,
  "date_created": "example string",
  "hour_created": "example string",
  "type_archive": "example string",
  "file_name": "example string",
  "extension_archive": "example string",
  "route_archive": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Archives POST',
      apiUrl: '${baseUrl}/Archives',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ArchivesidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Archives/{id} GET',
      apiUrl: '${baseUrl}/Archives/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ArchivesidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_archive": 123,
  "id_company": 123,
  "date_created": "example string",
  "hour_created": "example string",
  "type_archive": "example string",
  "file_name": "example string",
  "extension_archive": "example string",
  "route_archive": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Archives/{id} PUT',
      apiUrl: '${baseUrl}/Archives/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ArchivesidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Archives/{id} DELETE',
      apiUrl: '${baseUrl}/Archives/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ArchivesFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Archives/filters GET',
      apiUrl: '${baseUrl}/Archives/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class BrazalsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Brazals GET',
      apiUrl: '${baseUrl}/Brazals',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class BrazalsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_brazal": 123,
  "id_headquarter_start": 123,
  "id_headquarter_finish": 123,
  "name_brazal": "example string",
  "line_start": 123,
  "line_finish": 123
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Brazals POST',
      apiUrl: '${baseUrl}/Brazals',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class BrazalsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Brazals/{id} GET',
      apiUrl: '${baseUrl}/Brazals/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class BrazalsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_brazal": 123,
  "id_headquarter_start": 123,
  "id_headquarter_finish": 123,
  "name_brazal": "example string",
  "line_start": 123,
  "line_finish": 123
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Brazals/{id} PUT',
      apiUrl: '${baseUrl}/Brazals/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class BrazalsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Brazals/{id} DELETE',
      apiUrl: '${baseUrl}/Brazals/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class BrazalsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Brazals/filters GET',
      apiUrl: '${baseUrl}/Brazals/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CompaniesGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Companies GET',
      apiUrl: '${baseUrl}/Companies',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CompaniesPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_company": 123,
  "name_company": "example string",
  "business_name": "example string",
  "nit": "example string",
  "address": "example string",
  "telePhone": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Companies POST',
      apiUrl: '${baseUrl}/Companies',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CompaniesidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Companies/{id} GET',
      apiUrl: '${baseUrl}/Companies/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CompaniesidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_company": 123,
  "name_company": "example string",
  "business_name": "example string",
  "nit": "example string",
  "address": "example string",
  "telePhone": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Companies/{id} PUT',
      apiUrl: '${baseUrl}/Companies/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CompaniesidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Companies/{id} DELETE',
      apiUrl: '${baseUrl}/Companies/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CompaniesFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Companies/filters GET',
      apiUrl: '${baseUrl}/Companies/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CyclesGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Cycles GET',
      apiUrl: '${baseUrl}/Cycles',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CyclesPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_cycle": 123,
  "order_cycle": 123,
  "cycle": 123,
  "score": 0
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Cycles POST',
      apiUrl: '${baseUrl}/Cycles',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CyclesidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Cycles/{id} GET',
      apiUrl: '${baseUrl}/Cycles/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CyclesidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_cycle": 123,
  "order_cycle": 123,
  "cycle": 123,
  "score": 0
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Cycles/{id} PUT',
      apiUrl: '${baseUrl}/Cycles/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CyclesidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Cycles/{id} DELETE',
      apiUrl: '${baseUrl}/Cycles/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class CyclesFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Cycles/filters GET',
      apiUrl: '${baseUrl}/Cycles/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DashboardsGetDashboardMainPOSTCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Dashboards/GetDashboardMain POST',
      apiUrl: '${baseUrl}/Dashboards/GetDashboardMain',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DevicesGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Devices GET',
      apiUrl: '${baseUrl}/Devices',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DevicesPOSTCall {
  Future<ApiCallResponse> call({
    int? idDevice,
    int? idCompany,
    String? deviceName,
    String? cellPhone,
    String? serialId,
    String? imeI1,
    String? imeI2,
    String? model,
    String? state,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_device": ${idDevice ?? 0},
  "id_company": ${idCompany ?? 0},
  "device_name": "${deviceName ?? ''}",
  "cell_phone": "${cellPhone ?? ''}",
  "serial_id": "${serialId ?? ''}",
  "i_m_e_i1": "${imeI1 ?? ''}",
  "i_m_e_i2": "${imeI2 ?? ''}",
  "model": "${model ?? ''}",
  "state": "${state ?? 'A'}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Devices POST',
      apiUrl: '${baseUrl}/Devices',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DevicesidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Devices/{id} GET',
      apiUrl: '${baseUrl}/Devices/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DevicesidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_device": 123,
  "id_company": 123,
  "device_name": "example string",
  "cellPhone": "example string",
  "serial_id": "example string",
  "imeI1": "example string",
  "imeI2": "example string",
  "model": "example string",
  "state": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Devices/{id} PUT',
      apiUrl: '${baseUrl}/Devices/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DevicesidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Devices/{id} DELETE',
      apiUrl: '${baseUrl}/Devices/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class DevicesFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
    int? daysToProcess,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Devices/filters GET',
      apiUrl: '${baseUrl}/Devices/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
        'DaysToProcess': daysToProcess,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class FlowersGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Flowers GET',
      apiUrl: '${baseUrl}/Flowers',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class FlowersPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_flower": 123,
  "id_product": 123,
  "created_at": "example string",
  "state_product": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Flowers POST',
      apiUrl: '${baseUrl}/Flowers',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class FlowersidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Flowers/{id} GET',
      apiUrl: '${baseUrl}/Flowers/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class FlowersidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_flower": 123,
  "id_product": 123,
  "created_at": "example string",
  "state_product": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Flowers/{id} PUT',
      apiUrl: '${baseUrl}/Flowers/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class FlowersidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Flowers/{id} DELETE',
      apiUrl: '${baseUrl}/Flowers/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class FlowersFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Flowers/filters GET',
      apiUrl: '${baseUrl}/Flowers/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GroupsMetricsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Groups_metrics GET',
      apiUrl: '${baseUrl}/Groups_metrics',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GroupsMetricsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_group_metric": 123,
  "id_company": 123,
  "name_group_metric": "example string",
  "order_metric": 123
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Groups_metrics POST',
      apiUrl: '${baseUrl}/Groups_metrics',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GroupsMetricsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Groups_metrics/{id} GET',
      apiUrl: '${baseUrl}/Groups_metrics/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GroupsMetricsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_group_metric": 123,
  "id_company": 123,
  "name_group_metric": "example string",
  "order_metric": 123
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Groups_metrics/{id} PUT',
      apiUrl: '${baseUrl}/Groups_metrics/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GroupsMetricsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Groups_metrics/{id} DELETE',
      apiUrl: '${baseUrl}/Groups_metrics/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class GroupsMetricsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Groups_metrics/filters GET',
      apiUrl: '${baseUrl}/Groups_metrics/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters GET',
      apiUrl: '${baseUrl}/Headquarters',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_headquarter": 123,
  "id_zone": 123,
  "created_at": "example string",
  "name_headquarter": "example string",
  "density_headquarter": 0,
  "seed_time": "example string",
  "state_headquarter": "example string",
  "area_headquarter": 0,
  "polygon": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters POST',
      apiUrl: '${baseUrl}/Headquarters',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters/{id} GET',
      apiUrl: '${baseUrl}/Headquarters/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_headquarter": 123,
  "id_zone": 123,
  "created_at": "example string",
  "name_headquarter": "example string",
  "density_headquarter": 0,
  "seed_time": "example string",
  "state_headquarter": "example string",
  "area_headquarter": 0,
  "polygon": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters/{id} PUT',
      apiUrl: '${baseUrl}/Headquarters/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters/{id} DELETE',
      apiUrl: '${baseUrl}/Headquarters/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters/filters GET',
      apiUrl: '${baseUrl}/Headquarters/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersWeightsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters_weights GET',
      apiUrl: '${baseUrl}/Headquarters_weights',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersWeightsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_headquarter_weight": 123,
  "id_headquarter": 123,
  "id_activity": 123,
  "weight": 0
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters_weights POST',
      apiUrl: '${baseUrl}/Headquarters_weights',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersWeightsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters_weights/{id} GET',
      apiUrl: '${baseUrl}/Headquarters_weights/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersWeightsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_headquarter_weight": 123,
  "id_headquarter": 123,
  "id_activity": 123,
  "weight": 0
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters_weights/{id} PUT',
      apiUrl: '${baseUrl}/Headquarters_weights/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersWeightsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters_weights/{id} DELETE',
      apiUrl: '${baseUrl}/Headquarters_weights/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class HeadquartersWeightsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Headquarters_weights/filters GET',
      apiUrl: '${baseUrl}/Headquarters_weights/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics GET',
      apiUrl: '${baseUrl}/Metrics',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_metric": 123,
  "id_group_metric": 123,
  "name_metric": "example string",
  "score": 0
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Metrics POST',
      apiUrl: '${baseUrl}/Metrics',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics/{id} GET',
      apiUrl: '${baseUrl}/Metrics/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_metric": 123,
  "id_group_metric": 123,
  "name_metric": "example string",
  "score": 0
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Metrics/{id} PUT',
      apiUrl: '${baseUrl}/Metrics/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics/{id} DELETE',
      apiUrl: '${baseUrl}/Metrics/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsFiltersGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_filters GET',
      apiUrl: '${baseUrl}/Metrics_filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsFiltersPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_metric_filter": 123,
  "id_metric": 123,
  "name_metric_filter": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_filters POST',
      apiUrl: '${baseUrl}/Metrics_filters',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsFiltersidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_filters/{id} GET',
      apiUrl: '${baseUrl}/Metrics_filters/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsFiltersidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_metric_filter": 123,
  "id_metric": 123,
  "name_metric_filter": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_filters/{id} PUT',
      apiUrl: '${baseUrl}/Metrics_filters/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsFiltersidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_filters/{id} DELETE',
      apiUrl: '${baseUrl}/Metrics_filters/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsFiltersFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_filters/filters GET',
      apiUrl: '${baseUrl}/Metrics_filters/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsItemsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_items GET',
      apiUrl: '${baseUrl}/Metrics_items',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsItemsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_metric_item": 123,
  "id_metric": 123,
  "name_metric_item": "example string",
  "url_metric_item": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_items POST',
      apiUrl: '${baseUrl}/Metrics_items',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsItemsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_items/{id} GET',
      apiUrl: '${baseUrl}/Metrics_items/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsItemsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_metric_item": 123,
  "id_metric": 123,
  "name_metric_item": "example string",
  "url_metric_item": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_items/{id} PUT',
      apiUrl: '${baseUrl}/Metrics_items/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsItemsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_items/{id} DELETE',
      apiUrl: '${baseUrl}/Metrics_items/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class MetricsItemsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Metrics_items/filters GET',
      apiUrl: '${baseUrl}/Metrics_items/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration GET',
      apiUrl: '${baseUrl}/Polinization_configuration',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_polinization_configuration": 123,
  "id_activity": 123
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration POST',
      apiUrl: '${baseUrl}/Polinization_configuration',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration/{id} GET',
      apiUrl: '${baseUrl}/Polinization_configuration/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_polinization_configuration": 123,
  "id_activity": 123
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration/{id} PUT',
      apiUrl: '${baseUrl}/Polinization_configuration/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration/{id} DELETE',
      apiUrl: '${baseUrl}/Polinization_configuration/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration/filters GET',
      apiUrl: '${baseUrl}/Polinization_configuration/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationStatusGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration_status GET',
      apiUrl: '${baseUrl}/Polinization_configuration_status',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationStatusPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_polinization_configuration_status": 123,
  "id_status": 123,
  "type_polinization_configuration_status": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration_status POST',
      apiUrl: '${baseUrl}/Polinization_configuration_status',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationStatusidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration_status/{id} GET',
      apiUrl: '${baseUrl}/Polinization_configuration_status/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationStatusidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_polinization_configuration_status": 123,
  "id_status": 123,
  "type_polinization_configuration_status": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration_status/{id} PUT',
      apiUrl: '${baseUrl}/Polinization_configuration_status/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationStatusidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration_status/{id} DELETE',
      apiUrl: '${baseUrl}/Polinization_configuration_status/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationConfigurationStatusFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinization_configuration_status/filters GET',
      apiUrl: '${baseUrl}/Polinization_configuration_status/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationsFlowersGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinizations_flowers GET',
      apiUrl: '${baseUrl}/Polinizations_flowers',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationsFlowersPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_polinization": 123,
  "id_flower": 123,
  "id_visit": 123,
  "date_created": "example string",
  "hour_created": "example string",
  "id_activity": 123,
  "id_cycle": 123
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Polinizations_flowers POST',
      apiUrl: '${baseUrl}/Polinizations_flowers',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationsFlowersidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinizations_flowers/{id} GET',
      apiUrl: '${baseUrl}/Polinizations_flowers/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationsFlowersidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_polinization": 123,
  "id_flower": 123,
  "id_visit": 123,
  "date_created": "example string",
  "hour_created": "example string",
  "id_activity": 123,
  "id_cycle": 123
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Polinizations_flowers/{id} PUT',
      apiUrl: '${baseUrl}/Polinizations_flowers/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationsFlowersidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinizations_flowers/{id} DELETE',
      apiUrl: '${baseUrl}/Polinizations_flowers/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PolinizationsFlowersFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Polinizations_flowers/filters GET',
      apiUrl: '${baseUrl}/Polinizations_flowers/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PricesProductsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Prices_products GET',
      apiUrl: '${baseUrl}/Prices_products',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PricesProductsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_price_product": 123,
  "id_product": 123,
  "type_price": "example string",
  "value_product": 0
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Prices_products POST',
      apiUrl: '${baseUrl}/Prices_products',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PricesProductsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Prices_products/{id} GET',
      apiUrl: '${baseUrl}/Prices_products/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PricesProductsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_price_product": 123,
  "id_product": 123,
  "type_price": "example string",
  "value_product": 0
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Prices_products/{id} PUT',
      apiUrl: '${baseUrl}/Prices_products/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PricesProductsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Prices_products/{id} DELETE',
      apiUrl: '${baseUrl}/Prices_products/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class PricesProductsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Prices_products/filters GET',
      apiUrl: '${baseUrl}/Prices_products/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ProductsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Products GET',
      apiUrl: '${baseUrl}/Products',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ProductsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_product": 123,
  "id_brazal": 123,
  "id_headquarter": 123,
  "id_company": 123,
  "name_product": "example string",
  "type_product": "example string",
  "rfid": "example string",
  "created_at": "example string",
  "modified_at": "example string",
  "state_product": "example string",
  "description_product": "example string",
  "line": 123,
  "palm": 123
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Products POST',
      apiUrl: '${baseUrl}/Products',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ProductsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Products/{id} GET',
      apiUrl: '${baseUrl}/Products/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ProductsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_product": 123,
  "id_brazal": 123,
  "id_headquarter": 123,
  "id_company": 123,
  "name_product": "example string",
  "type_product": "example string",
  "rfid": "example string",
  "created_at": "example string",
  "modified_at": "example string",
  "state_product": "example string",
  "description_product": "example string",
  "line": 123,
  "palm": 123
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Products/{id} PUT',
      apiUrl: '${baseUrl}/Products/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ProductsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Products/{id} DELETE',
      apiUrl: '${baseUrl}/Products/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ProductsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Products/filters GET',
      apiUrl: '${baseUrl}/Products/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ReportsReportsDailysPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Reports/ReportsDailys POST',
      apiUrl: '${baseUrl}/Reports/ReportsDailys',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ReportsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Reports GET',
      apiUrl: '${baseUrl}/Reports',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ReportsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_report": 123,
  "id_company": 123,
  "report_name": "example string",
  "date_created": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Reports POST',
      apiUrl: '${baseUrl}/Reports',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ReportsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Reports/{id} GET',
      apiUrl: '${baseUrl}/Reports/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ReportsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_report": 123,
  "id_company": 123,
  "report_name": "example string",
  "date_created": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Reports/{id} PUT',
      apiUrl: '${baseUrl}/Reports/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ReportsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Reports/{id} DELETE',
      apiUrl: '${baseUrl}/Reports/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ReportsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Reports/filters GET',
      apiUrl: '${baseUrl}/Reports/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class StockProductsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Stock_products GET',
      apiUrl: '${baseUrl}/Stock_products',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class StockProductsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_stock_product": 123,
  "id_product": 123,
  "state_stock": "example string",
  "created_at": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Stock_products POST',
      apiUrl: '${baseUrl}/Stock_products',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class StockProductsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Stock_products/{id} GET',
      apiUrl: '${baseUrl}/Stock_products/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class StockProductsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_stock_product": 123,
  "id_product": 123,
  "state_stock": "example string",
  "created_at": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Stock_products/{id} PUT',
      apiUrl: '${baseUrl}/Stock_products/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class StockProductsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Stock_products/{id} DELETE',
      apiUrl: '${baseUrl}/Stock_products/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class StockProductsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Stock_products/filters GET',
      apiUrl: '${baseUrl}/Stock_products/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SyncTimesSyncFullPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Sync_times/SyncFull POST',
      apiUrl: '${baseUrl}/Sync_times/SyncFull',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SyncTimesSyncFlowersPOSTCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Sync_times/SyncFlowers POST',
      apiUrl: '${baseUrl}/Sync_times/SyncFlowers',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SyncTimesGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Sync_times GET',
      apiUrl: '${baseUrl}/Sync_times',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SyncTimesPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_sync": 123,
  "created_at": "example string",
  "hour_at": "example string",
  "table_name": "example string",
  "last_item": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Sync_times POST',
      apiUrl: '${baseUrl}/Sync_times',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SyncVisitsAddCall {
  Future<ApiCallResponse> call({
    dynamic? visitsAddListJson,
    dynamic? newsAddListJson,
    String? createdAt = '',
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final visitsAddList = _serializeJson(visitsAddListJson, true);
    final newsAddList = _serializeJson(newsAddListJson, true);
    final ffApiRequestBody = '''
{
  "createdAt": "${createdAt}",
  "visitsAdd": ${visitsAddList},
  "newsAdd": ${newsAddList}
}''';
    return ApiManager.instance.makeApiCall(
      callName: 'SyncVisitsAdd',
      apiUrl: '${baseUrl}/Sync_times/SyncVisitsAdd',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SyncTimesidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Sync_times/{id} GET',
      apiUrl: '${baseUrl}/Sync_times/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SyncTimesidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_sync": 123,
  "created_at": "example string",
  "hour_at": "example string",
  "table_name": "example string",
  "last_item": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Sync_times/{id} PUT',
      apiUrl: '${baseUrl}/Sync_times/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SyncTimesidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Sync_times/{id} DELETE',
      apiUrl: '${baseUrl}/Sync_times/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class SyncTimesFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Sync_times/filters GET',
      apiUrl: '${baseUrl}/Sync_times/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class TasksGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Tasks GET',
      apiUrl: '${baseUrl}/Tasks',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class TasksPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_task": 123,
  "id_company": 123,
  "date_created": "example string",
  "hour_created": "example string",
  "description_task": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Tasks POST',
      apiUrl: '${baseUrl}/Tasks',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class TasksidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Tasks/{id} GET',
      apiUrl: '${baseUrl}/Tasks/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class TasksidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_task": 123,
  "id_company": 123,
  "date_created": "example string",
  "hour_created": "example string",
  "description_task": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Tasks/{id} PUT',
      apiUrl: '${baseUrl}/Tasks/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class TasksidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Tasks/{id} DELETE',
      apiUrl: '${baseUrl}/Tasks/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class TasksFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Tasks/filters GET',
      apiUrl: '${baseUrl}/Tasks/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersLoginPOSTCall {
  Future<ApiCallResponse> call({
    String? typeLogin = '',
    String? username = '',
    String? password = '',
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "type_login": "${typeLogin}",
  "username": "${username}",
  "password": "${password}"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Users/Login POST',
      apiUrl: '${baseUrl}/Users/Login',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users GET',
      apiUrl: '${baseUrl}/Users',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_user": 123,
  "id_company": 123,
  "operID": "example string",
  "name_user": "example string",
  "email": "example string",
  "created_at": "example string",
  "modifiedAt": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Users POST',
      apiUrl: '${baseUrl}/Users',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users/{id} GET',
      apiUrl: '${baseUrl}/Users/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_user": 123,
  "id_company": 123,
  "operID": "example string",
  "name_user": "example string",
  "email": "example string",
  "created_at": "example string",
  "modifiedAt": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Users/{id} PUT',
      apiUrl: '${baseUrl}/Users/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users/{id} DELETE',
      apiUrl: '${baseUrl}/Users/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users/filters GET',
      apiUrl: '${baseUrl}/Users/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersbyoperidGETCall {
  Future<ApiCallResponse> call({
    required String operID,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users/by-operid/{operID} GET',
      apiUrl: '${baseUrl}/Users/by-operid/${operID}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ValidateSupervisorGETCall {
  Future<ApiCallResponse> call({
    required String code,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/users/validate-supervisor/{code} GET',
      apiUrl: '${baseUrl}/users/validate-supervisor/${code}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersCredentialsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_credentials GET',
      apiUrl: '${baseUrl}/Users_credentials',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersCredentialsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_user_credential": 123,
  "id_user": 123,
  "user_name_login": "example string",
  "password_login": "example string",
  "createdAt": "example string",
  "modifiedAt": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Users_credentials POST',
      apiUrl: '${baseUrl}/Users_credentials',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersCredentialsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_credentials/{id} GET',
      apiUrl: '${baseUrl}/Users_credentials/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersCredentialsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_user_credential": 123,
  "id_user": 123,
  "user_name_login": "example string",
  "password_login": "example string",
  "createdAt": "example string",
  "modifiedAt": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Users_credentials/{id} PUT',
      apiUrl: '${baseUrl}/Users_credentials/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersCredentialsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_credentials/{id} DELETE',
      apiUrl: '${baseUrl}/Users_credentials/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersCredentialsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_credentials/filters GET',
      apiUrl: '${baseUrl}/Users_credentials/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersDevicesGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_devices GET',
      apiUrl: '${baseUrl}/Users_devices',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersDevicesPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_user_device": 123,
  "created_at": "example string",
  "modifiedAt": "example string",
  "id_user": 123,
  "imei1": "example string",
  "imei2": "example string",
  "status": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Users_devices POST',
      apiUrl: '${baseUrl}/Users_devices',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersDevicesidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_devices/{id} GET',
      apiUrl: '${baseUrl}/Users_devices/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersDevicesidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_user_device": 123,
  "created_at": "example string",
  "modifiedAt": "example string",
  "id_user": 123,
  "imei1": "example string",
  "imei2": "example string",
  "status": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Users_devices/{id} PUT',
      apiUrl: '${baseUrl}/Users_devices/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersDevicesidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_devices/{id} DELETE',
      apiUrl: '${baseUrl}/Users_devices/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersDevicesFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_devices/filters GET',
      apiUrl: '${baseUrl}/Users_devices/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersPermissionsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_permissions GET',
      apiUrl: '${baseUrl}/Users_permissions',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersPermissionsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_user_permission": 123,
  "id_user": 123,
  "permission_type": "example string",
  "created_at": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Users_permissions POST',
      apiUrl: '${baseUrl}/Users_permissions',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersPermissionsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_permissions/{id} GET',
      apiUrl: '${baseUrl}/Users_permissions/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersPermissionsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_user_permission": 123,
  "id_user": 123,
  "permission_type": "example string",
  "created_at": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Users_permissions/{id} PUT',
      apiUrl: '${baseUrl}/Users_permissions/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersPermissionsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_permissions/{id} DELETE',
      apiUrl: '${baseUrl}/Users_permissions/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class UsersPermissionsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Users_permissions/filters GET',
      apiUrl: '${baseUrl}/Users_permissions/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits GET',
      apiUrl: '${baseUrl}/Visits',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_visit": 123,
  "id_company": 123,
  "created_at": "example string",
  "description_visit": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Visits POST',
      apiUrl: '${baseUrl}/Visits',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits/{id} GET',
      apiUrl: '${baseUrl}/Visits/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_visit": 123,
  "id_company": 123,
  "created_at": "example string",
  "description_visit": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Visits/{id} PUT',
      apiUrl: '${baseUrl}/Visits/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits/{id} DELETE',
      apiUrl: '${baseUrl}/Visits/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits/filters GET',
      apiUrl: '${baseUrl}/Visits/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsBulkGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits_bulk GET',
      apiUrl: '${baseUrl}/Visits_bulk',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsBulkPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_bulk_visit": 123,
  "id_visit": 123,
  "created_at": "example string",
  "state_visit": "example string",
  "description_visit": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Visits_bulk POST',
      apiUrl: '${baseUrl}/Visits_bulk',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsBulkidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits_bulk/{id} GET',
      apiUrl: '${baseUrl}/Visits_bulk/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsBulkidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_bulk_visit": 123,
  "id_visit": 123,
  "created_at": "example string",
  "state_visit": "example string",
  "description_visit": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Visits_bulk/{id} PUT',
      apiUrl: '${baseUrl}/Visits_bulk/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsBulkidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits_bulk/{id} DELETE',
      apiUrl: '${baseUrl}/Visits_bulk/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsBulkFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits_bulk/filters GET',
      apiUrl: '${baseUrl}/Visits_bulk/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsPolinizationsStatusGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits_polinizations_status GET',
      apiUrl: '${baseUrl}/Visits_polinizations_status',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsPolinizationsStatusPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_polinization_status": 123,
  "id_visit": 123,
  "created_at": "example string",
  "state_visit": "example string",
  "description_visit": "example string",
  "status": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Visits_polinizations_status POST',
      apiUrl: '${baseUrl}/Visits_polinizations_status',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsPolinizationsStatusidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits_polinizations_status/{id} GET',
      apiUrl: '${baseUrl}/Visits_polinizations_status/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsPolinizationsStatusidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_polinization_status": 123,
  "id_visit": 123,
  "created_at": "example string",
  "state_visit": "example string",
  "description_visit": "example string",
  "status": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Visits_polinizations_status/{id} PUT',
      apiUrl: '${baseUrl}/Visits_polinizations_status/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsPolinizationsStatusidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits_polinizations_status/{id} DELETE',
      apiUrl: '${baseUrl}/Visits_polinizations_status/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class VisitsPolinizationsStatusFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Visits_polinizations_status/filters GET',
      apiUrl: '${baseUrl}/Visits_polinizations_status/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ZonesGETCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Zones GET',
      apiUrl: '${baseUrl}/Zones',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ZonesPOSTCall {
  Future<ApiCallResponse> call() async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_zone": 123,
  "id_company": 123,
  "created_at": "example string",
  "name_zone": "example string",
  "difficulty": 123,
  "state_zone": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Zones POST',
      apiUrl: '${baseUrl}/Zones',
      callType: ApiCallType.POST,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ZonesidGETCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Zones/{id} GET',
      apiUrl: '${baseUrl}/Zones/${id}',
      callType: ApiCallType.GET,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ZonesidPUTCall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    final ffApiRequestBody = '''
{
  "id_zone": 123,
  "id_company": 123,
  "created_at": "example string",
  "name_zone": "example string",
  "difficulty": 123,
  "state_zone": "example string"
}''';
    return ApiManager.instance.makeApiCall(
      callName: '/Zones/{id} PUT',
      apiUrl: '${baseUrl}/Zones/${id}',
      callType: ApiCallType.PUT,
      headers: {},
      params: {},
      body: ffApiRequestBody,
      bodyType: BodyType.JSON,
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ZonesidDELETECall {
  Future<ApiCallResponse> call({
    int? id,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Zones/{id} DELETE',
      apiUrl: '${baseUrl}/Zones/${id}',
      callType: ApiCallType.DELETE,
      headers: {},
      params: {},
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ZonesFiltersGETCall {
  Future<ApiCallResponse> call({
    String? typeSearch = '',
    String? textSearch1 = '',
    String? textSearch2 = '',
    int? idCompany,
  }) async {
    final baseUrl = APIClickPalmGroup.getBaseUrl();

    return ApiManager.instance.makeApiCall(
      callName: '/Zones/filters GET',
      apiUrl: '${baseUrl}/Zones/filters',
      callType: ApiCallType.GET,
      headers: {},
      params: {
        'Type_search': typeSearch,
        'Text_search1': textSearch1,
        'Text_search2': textSearch2,
        'Id_company': idCompany,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

/// End API ClickPalm Group Code

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}

String _toEncodable(dynamic item) {
  return item;
}

String _serializeList(List? list) {
  list ??= <String>[];
  try {
    return json.encode(list, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("List serialization failed. Returning empty list.");
    }
    return '[]';
  }
}

String _serializeJson(dynamic jsonVar, [bool isList = false]) {
  jsonVar ??= (isList ? [] : {});
  try {
    return json.encode(jsonVar, toEncodable: _toEncodable);
  } catch (_) {
    if (kDebugMode) {
      print("Json serialization failed. Returning empty json.");
    }
    return isList ? '[]' : '{}';
  }
}
