// lib/services/rabbitmq_user_service.dart (VERSÃO CORRIGIDA)

import 'package:dart_amqp/dart_amqp.dart';

class RabbitMQUserService {
  late Client _client;
  late Channel _channel;
  late Queue _userQueue; // Manter a referência da fila do usuário
  final String _username;

  RabbitMQUserService(this._username);

  ConnectionSettings settings = ConnectionSettings(
    host: "localhost",
    authProvider: const PlainAuthenticator("guest", "guest"),
  );

  Future<void> connect() async {
    _client = Client(settings: settings);
    _channel = await _client.channel();
    // Garante que a fila durável do usuário existe e a armazena
    _userQueue = await _channel.queue(_username, durable: true);
  }

  Future<void> sendDirectMessage(String recipientUsername, String message) async {
    // A lógica aqui continua a mesma. Publica diretamente na fila do destinatário.
    Queue queue = await _channel.queue(recipientUsername, durable: true);
    queue.publish(message);
  }

  Future<void> sendMessageToTopic(String topicName, String message) async {
    Exchange exchange = await _channel.exchange(topicName, ExchangeType.TOPIC, durable: true);
    // Publica na exchange. O routing key é o próprio nome do tópico.
    exchange.publish(message, topicName);
  }

  // --- MÉTODO CORRIGIDO ---
  // Agora ele apenas cria a ligação (binding), não uma nova fila.
  Future<void> subscribeToTopic(String topicName) async {
    Exchange exchange = await _channel.exchange(topicName, ExchangeType.TOPIC, durable: true);
    // Liga a fila PERMANENTE do usuário à exchange do tópico.
    // O routing key é o nome do tópico, para receber mensagens desse tópico.
    await _userQueue.bind(exchange, topicName);
  }

  // --- MÉTODO UNIFICADO PARA OUVIR MENSAGENS ---
  // Este método substitui o 'listenToDirectMessages'
  Future<void> listenToMessages(void Function(AmqpMessage) onMessageReceived) async {
    // Começa a consumir da fila principal do usuário.
    Consumer consumer = await _userQueue.consume();
    consumer.listen((AmqpMessage event) {
      // Passamos a mensagem inteira (AmqpMessage) para o callback.
      // Isso permite que a UI saiba se a mensagem veio de um tópico ou foi direta.
      onMessageReceived(event);
    });
  }

  void dispose() {
    _client.close();
  }
}
