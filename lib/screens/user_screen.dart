import 'package:dart_amqp/dart_amqp.dart';
import 'package:flutter/material.dart';
import '../services/rabbitmq_user_service.dart';

class UserLoginScreen extends StatelessWidget {
  const UserLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('Login de Usuário')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Seu nome de usuário',
                  hintText: 'Deve ser um usuário criado pelo Gerenciador',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserChatScreen(username: controller.text),
                      ),
                    );
                  }
                },
                child: const Text('Entrar'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class UserChatScreen extends StatefulWidget {
  final String username;
  const UserChatScreen({super.key, required this.username});

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  late final RabbitMQUserService _userService;
  final List<String> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userService = RabbitMQUserService(widget.username);
    _connectAndListen();
  }

  void _connectAndListen() async {
    try {
      await _userService.connect();

      _userService.listenToMessages((AmqpMessage message) {
        String displayText;
        // O routingKey para mensagens diretas é o nome da própria fila (username)
        // O routingKey para mensagens de tópico é o nome do tópico
        final routingKey = message.routingKey;
        final payload = message.payloadAsString;

        if (routingKey == widget.username) {
          // Podemos assumir que é uma mensagem direta.
          // Para ser mais preciso, você poderia adicionar um header na mensagem indicando o remetente.
          displayText = 'Direct: $payload';
        } else {
          // Se o routingKey não for o username, é um tópico.
          displayText = 'Tópico[$routingKey]: $payload';
        }

        if (mounted) setState(() => _messages.insert(0, displayText));
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao conectar: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _userService.dispose();
    _messageController.dispose();
    _recipientController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final message = _messageController.text;
    final recipient = _recipientController.text;
    final topic = _topicController.text;

    if (message.isEmpty) return;

    if (recipient.isNotEmpty) {
      _userService.sendDirectMessage(recipient, message);
      setState(() => _messages.insert(0, 'Você para $recipient: $message'));
    } else if (topic.isNotEmpty) {
      _userService.sendMessageToTopic(topic, message);
      setState(() => _messages.insert(0, 'Você para Tópico[$topic]: $message'));
    }
    _messageController.clear();
  }

  void _subscribeToTopic() async {
    final topic = _topicController.text;
    if (topic.isEmpty) return;

    try {
      // Simplesmente chama o novo método sem callback
      await _userService.subscribeToTopic(topic);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Inscrito no tópico: $topic')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao inscrever-se: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat - ${widget.username}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _recipientController,
                        decoration: const InputDecoration(labelText: 'Destinatário (Usuário)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _topicController,
                        decoration: const InputDecoration(labelText: 'Tópico'),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_link),
                      onPressed: _subscribeToTopic,
                      tooltip: 'Assinar Tópico',
                    ),
                  ],
                ),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(labelText: 'Sua mensagem...'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _sendMessage,
                  child: const Text('Enviar Mensagem'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) => ListTile(title: Text(_messages[index])),
            ),
          ),
        ],
      ),
    );
  }
}
