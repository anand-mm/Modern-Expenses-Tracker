abstract class MerchantMappingEvent {}

class LoadMerchantMappings extends MerchantMappingEvent {}

class AddMerchantMapping extends MerchantMappingEvent {
  final String rawName;
  final String friendlyName;

  AddMerchantMapping({required this.rawName, required this.friendlyName});
}

class DeleteMerchantMapping extends MerchantMappingEvent {
  final String rawName;

  DeleteMerchantMapping({required this.rawName});
}
