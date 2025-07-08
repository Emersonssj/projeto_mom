import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class RabbitMQManagerService {
  final String _baseUrl = 'localhost:15672';
  final String _vhost = '%2F';
  final String _credentials = 'guest:guest';

  // Codifica as credenciais para o cabeçalho de autorização
  String get _basicAuth => 'Basic ${base64Encode(utf8.encode(_credentials))}';

  // Cabeçalhos padrão para as requisições
  Map<String, String> get _headers => {
        HttpHeaders.authorizationHeader: _basicAuth,
        HttpHeaders.contentTypeHeader: 'application/json',
      };

  Future<List<dynamic>> listQueues() async {
    final response = await http.get(Uri.http(_baseUrl, '/api/queues/'), headers: _headers);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to load queues: ${response.body}');
  }

  Future<List<dynamic>> listTopics() async {
    // No RabbitMQ, "tópicos" são exchanges do tipo 'topic'
    final response = await http.get(Uri.http(_baseUrl, '/api/exchanges/'), headers: _headers);
    if (response.statusCode == 200) {
      final allExchanges = json.decode(response.body) as List;
      return allExchanges.where((ex) => ex['type'] == 'topic' && !ex['name'].startsWith('amq.')).toList();
    }
    throw Exception('Failed to load topics: ${response.body}');
  }

  Future<bool> createQueue(String queueName) async {
    final body = json.encode({'auto_delete': false, 'durable': true});
    final response = await http.put(
      Uri.parse('http://$_baseUrl/api/queues/$_vhost/$queueName'),
      headers: _headers,
      body: body,
    );
    return response.statusCode == 201 || response.statusCode == 204;
  }

  Future<bool> deleteQueue(String queueName) async {
    final response = await http.delete(
      Uri.parse('http://$_baseUrl/api/queues/$_vhost/$queueName'),
      headers: _headers,
    );
    return response.statusCode == 204;
  }

  Future<bool> createTopic(String topicName) async {
    final body = json.encode({'type': 'topic', 'auto_delete': false, 'durable': true});
    final response = await http.put(
      Uri.parse('http://$_baseUrl/api/exchanges/$_vhost/$topicName'),
      headers: _headers,
      body: body,
    );
    return response.statusCode == 201 || response.statusCode == 204;
  }

  Future<bool> deleteTopic(String topicName) async {
    final response = await http.delete(
      Uri.parse('http://$_baseUrl/api/exchanges/$_vhost/$topicName'),
      headers: _headers,
    );
    return response.statusCode == 204;
  }

  //Criar usuário e sua fila automaticamente
  Future<bool> createUser(String username) async {
    return await createQueue(username);
  }
}
