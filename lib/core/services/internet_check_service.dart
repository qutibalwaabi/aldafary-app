import 'package:connectivity_plus/connectivity_plus.dart';

class InternetCheckService {
  static Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      // Additional check: Try to reach a reliable server
      // For now, we'll rely on connectivity result
      return true;
    } catch (e) {
      return false;
    }
  }
}

