import 'package:dio/dio.dart';
import '../../models/plugin.dart';
import '../../models/tool.dart';
import '../../models/tool_result.dart';
import '../../services/tool_registry.dart';
import '../../services/tool_executor.dart';
import '../../services/plugin_service.dart';
import '../../../core/security/secure_storage.dart';

class StripePlugin {
  static const String id = 'stripe';
  static const String name = 'Stripe';
  static const String description = 'Manage Stripe payments and customers';

  static Plugin get plugin => Plugin(
        id: id,
        name: name,
        description: description,
        category: PluginCategory.payment,
        version: '1.0.0',
        author: 'Schatz',
      );

  static List<Tool> get tools => [
        Tool(
            id: 'payment.list',
            name: 'List Payments',
            description: 'List recent payments',
            pluginId: id,
            type: ToolType.read,
            parameters: {
              'limit': ToolParameter(
                  name: 'limit',
                  description: 'Limit',
                  type: ToolParameterType.int)
            }),
        Tool(
            id: 'customer.create',
            name: 'Create Customer',
            description: 'Create a new customer',
            pluginId: id,
            type: ToolType.write,
            parameters: {
              'email': ToolParameter(
                  name: 'email',
                  description: 'Email',
                  type: ToolParameterType.string,
                  required: true),
              'name': ToolParameter(
                  name: 'name',
                  description: 'Name',
                  type: ToolParameterType.string)
            }),
        Tool(
            id: 'invoice.create',
            name: 'Create Invoice',
            description: 'Create an invoice',
            pluginId: id,
            type: ToolType.write,
            parameters: {
              'customerId': ToolParameter(
                  name: 'customerId',
                  description: 'Customer ID',
                  type: ToolParameterType.string,
                  required: true)
            }),
      ];

  static void register() {
    ToolRegistry().registerPluginTools(id, tools);
    final executor = ToolExecutorService();
    executor.registerExecutor(id, 'payment.list', _listPayments);
    executor.registerExecutor(id, 'customer.create', _createCustomer);
    executor.registerExecutor(id, 'invoice.create', _createInvoice);
  }

  static Future<Dio> _getClient() async {
    String? token = await SecureStorage().read('plugin_auth_stripe');
    if (token == null) {
      final plugin = await PluginService().getInstalledPlugins().then(
            (plugins) => plugins.where((p) => p.id == id).firstOrNull,
          );
      token = plugin?.settings['secret_key'] as String?;
    }
    if (token == null) throw Exception('Stripe secret key not configured');
    return Dio(BaseOptions(
        baseUrl: 'https://api.stripe.com/v1',
        headers: {'Authorization': 'Bearer $token'}));
  }

  static Future<ToolResult> _listPayments(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.get('/payment_intents',
          queryParameters: {'limit': params['limit'] ?? 10});
      return ToolResult.success('Payments retrieved',
          data: {'payments': response.data['data']});
    } catch (e) {
      return ToolResult.failure('Failed: $e');
    }
  }

  static Future<ToolResult> _createCustomer(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client.post('/customers',
          data: {'email': params['email'], 'name': params['name']});
      return ToolResult.success('Customer created: ${response.data['id']}',
          data: response.data);
    } catch (e) {
      return ToolResult.failure('Failed: $e');
    }
  }

  static Future<ToolResult> _createInvoice(Map<String, dynamic> params) async {
    try {
      final client = await _getClient();
      final response = await client
          .post('/invoices', data: {'customer': params['customerId']});
      return ToolResult.success('Invoice created: ${response.data['id']}',
          data: response.data);
    } catch (e) {
      return ToolResult.failure('Failed: $e');
    }
  }
}
