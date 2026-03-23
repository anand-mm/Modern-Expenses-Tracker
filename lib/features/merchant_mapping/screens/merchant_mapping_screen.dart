import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/merchant_mapping_bloc.dart';
import '../bloc/merchant_mapping_event.dart';
import '../bloc/merchant_mapping_state.dart';

class MerchantMappingScreen extends StatefulWidget {
  const MerchantMappingScreen({super.key});

  @override
  State<MerchantMappingScreen> createState() => _MerchantMappingScreenState();
}

class _MerchantMappingScreenState extends State<MerchantMappingScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MerchantMappingBloc>().add(LoadMerchantMappings());
  }

  Future<void> _showAddMappingDialog(BuildContext parentContext, List<String> rawMerchants) async {
    final rawNameController = TextEditingController();
    final friendlyNameController = TextEditingController();

    await showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Merchant Mapping'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return rawMerchants.where((String option) {
                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                });
              },
              onSelected: (String selection) {
                rawNameController.text = selection;
              },
              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  onChanged: (value) => rawNameController.text = value,
                  decoration: const InputDecoration(labelText: 'Raw Bank Name (e.g. VITHELINGAM)'),
                );
              },
            ),
            TextField(
              controller: friendlyNameController,
              decoration: const InputDecoration(labelText: 'Friendly Name (e.g. Teashop)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final rawName = rawNameController.text.trim();
              final friendlyName = friendlyNameController.text.trim();
              if (rawName.isNotEmpty && friendlyName.isNotEmpty) {
                parentContext.read<MerchantMappingBloc>().add(AddMerchantMapping(rawName: rawName, friendlyName: friendlyName));
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    rawNameController.dispose();
    friendlyNameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Merchants')),
      body: BlocBuilder<MerchantMappingBloc, MerchantMappingState>(
        builder: (context, state) {
          if (state is MerchantMappingLoading || state is MerchantMappingInitial) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is MerchantMappingError) {
            return Center(child: Text(state.message));
          } else if (state is MerchantMappingLoaded) {
            final mappings = state.mappings;
            if (mappings.isEmpty) {
              return const Center(child: Text('No custom merchant names yet.'));
            }

            return ListView.builder(
              itemCount: mappings.length,
              itemBuilder: (context, index) {
                final rawName = mappings.keys.elementAt(index);
                final friendlyName = mappings.values.elementAt(index);

                return ListTile(
                  title: Text(friendlyName),
                  subtitle: Text('Matches: $rawName'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      context.read<MerchantMappingBloc>().add(DeleteMerchantMapping(rawName: rawName));
                    },
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: BlocBuilder<MerchantMappingBloc, MerchantMappingState>(
        builder: (context, state) {
          List<String> rawMerchants = [];
          if (state is MerchantMappingLoaded) {
            rawMerchants = state.rawMerchants;
          }
          return FloatingActionButton(
            onPressed: () => _showAddMappingDialog(context, rawMerchants),
            child: const Icon(Icons.add),
          );
        },
      ),
    );
  }
}
