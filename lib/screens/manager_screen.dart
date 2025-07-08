import 'package:flutter/material.dart';
import '../services/rabbitmq_manager_service.dart';

class ManagerScreen extends StatefulWidget {
  const ManagerScreen({super.key});

  @override
  State<ManagerScreen> createState() => _ManagerScreenState();
}

class _ManagerScreenState extends State<ManagerScreen> {
  final RabbitMQManagerService _managerService = RabbitMQManagerService();
  late Future<List<dynamic>> _queues;
  late Future<List<dynamic>> _topics;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _queues = _managerService.listQueues();
      _topics = _managerService.listTopics();
    });
  }

  void _showAddDialog(String type) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Adicionar Novo $type'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Nome do $type'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                bool success = false;
                if (type == 'Queue') {
                  // Requisito: Criar fila [cite: 9]
                  success = await _managerService.createQueue(controller.text);
                } else if (type == 'User') {
                  // Requisito: Instanciar usuário e criar sua fila
                  success = await _managerService.createUser(controller.text);
                } else {
                  // Requisito: Criar tópico [cite: 9]
                  success = await _managerService.createTopic(controller.text);
                }
                if (success) _loadData();
                Navigator.pop(context);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Painel do Gerenciador MOM')),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSection(
              title: 'Usuários (Filas Individuais)',
              onAdd: () => _showAddDialog('User'),
              child: _buildList(_queues, 'queue',
                  (item) => !item['name'].startsWith('amq.') && item['arguments']?['x-exclusive'] != true),
            ),
            const SizedBox(height: 20),
            _buildSection(
              title: 'Tópicos',
              onAdd: () => _showAddDialog('Topic'),
              child: _buildList(_topics, 'topic', (item) => true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required VoidCallback onAdd, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            IconButton(icon: const Icon(Icons.add_circle), onPressed: onAdd, tooltip: 'Adicionar'),
          ],
        ),
        const Divider(),
        SizedBox(height: 200, child: child),
      ],
    );
  }

  Widget _buildList(Future<List<dynamic>> future, String type, bool Function(dynamic) filter) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erro: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Nenhum item encontrado.'));
        }

        final items = snapshot.data!.where(filter).toList();

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final name = item['name'];

            final messageCount = type == 'queue' ? item['messages'] ?? 0 : null;

            return Card(
              child: ListTile(
                title: Text(name),
                subtitle: messageCount != null ? Text('Mensagens: $messageCount') : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    bool success = false;
                    if (type == 'queue') {
                      success = await _managerService.deleteQueue(name);
                    } else {
                      success = await _managerService.deleteTopic(name);
                    }
                    if (success) _loadData();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
