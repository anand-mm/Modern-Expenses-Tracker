abstract class MerchantMappingState {}

class MerchantMappingInitial extends MerchantMappingState {}

class MerchantMappingLoading extends MerchantMappingState {}

class MerchantMappingLoaded extends MerchantMappingState {
  final Map<String, String> mappings;
  final List<String> rawMerchants;

  MerchantMappingLoaded({required this.mappings, required this.rawMerchants});
}

class MerchantMappingError extends MerchantMappingState {
  final String message;
  MerchantMappingError({required this.message});
}
