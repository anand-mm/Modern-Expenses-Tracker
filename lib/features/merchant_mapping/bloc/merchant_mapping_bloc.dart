import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/database/database_helper.dart';
import '../../sms_ingestion/parsers/sms_parser.dart';
import 'merchant_mapping_event.dart';
import 'merchant_mapping_state.dart';

class MerchantMappingBloc extends Bloc<MerchantMappingEvent, MerchantMappingState> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  MerchantMappingBloc() : super(MerchantMappingInitial()) {
    on<LoadMerchantMappings>(_onLoadMerchantMappings);
    on<AddMerchantMapping>(_onAddMerchantMapping);
    on<DeleteMerchantMapping>(_onDeleteMerchantMapping);
  }

  Future<void> _onLoadMerchantMappings(LoadMerchantMappings event, Emitter<MerchantMappingState> emit) async {
    emit(MerchantMappingLoading());
    try {
      final mappings = await _dbHelper.getAllMerchantMappings();
      final rawMerchants = await _dbHelper.getUniqueRawMerchants();
      emit(MerchantMappingLoaded(mappings: mappings, rawMerchants: rawMerchants));
    } catch (e) {
      emit(MerchantMappingError(message: 'Failed to load mappings: ${e.toString()}'));
    }
  }

  Future<void> _onAddMerchantMapping(AddMerchantMapping event, Emitter<MerchantMappingState> emit) async {
    try {
      await _dbHelper.insertMerchantMapping(event.rawName, event.friendlyName);
      await _reapplyMappingsToExistingTransactions();
      add(LoadMerchantMappings());
    } catch (e) {
      emit(MerchantMappingError(message: 'Failed to add mapping: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteMerchantMapping(DeleteMerchantMapping event, Emitter<MerchantMappingState> emit) async {
    try {
      await _dbHelper.deleteMerchantMappingByRawName(event.rawName);
      await _reapplyMappingsToExistingTransactions();
      add(LoadMerchantMappings());
    } catch (e) {
      emit(MerchantMappingError(message: 'Failed to delete mapping: ${e.toString()}'));
    }
  }

  Future<void> _reapplyMappingsToExistingTransactions() async {
    try {
      final parser = SmsParser(dbHelper: _dbHelper);
      final allTransactions = await _dbHelper.getAllTransactions();

      for (var tx in allTransactions) {
        if (tx.id != null) {
          final parsedTx = await parser.parseSms(tx.rawText);
          if (parsedTx != null && parsedTx.merchant != 'Unknown' && parsedTx.merchant != tx.merchant) {
            await _dbHelper.updateTransactionMerchant(tx.id!, parsedTx.merchant);
          }
        }
      }
    } catch (e) {
      // Fail silently for background tasks, user will just see mappings list.
    }
  }
}
