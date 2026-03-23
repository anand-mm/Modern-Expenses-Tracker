import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/dashboard/bloc/dashboard_bloc.dart';
import 'features/merchant_mapping/bloc/merchant_mapping_bloc.dart';
import 'features/main/screens/main_screen.dart';
import 'features/sms_ingestion/services/sms_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SMS listener
  final smsService = SmsService();
  await smsService.initSmsListener();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<DashboardBloc>(create: (_) => DashboardBloc()),
        BlocProvider<MerchantMappingBloc>(create: (_) => MerchantMappingBloc()),
      ],
      child: MaterialApp(
        title: 'Expense Tracker',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
