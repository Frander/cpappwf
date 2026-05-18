// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_util.dart';
// Imports other custom actions
// Imports custom functions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';

Future<String> uploadJsonToS3(dynamic jsonData, String bucket, String objectKey,
    String region, String accessKey, String secretKey) async {
  // 1. Serializar JSON
  final String payload = jsonEncode(jsonData);
  final Uint8List bodyBytes = utf8.encode(payload);

  // 2. URL completa del objeto
  final uri = Uri.parse('https://$bucket.s3.$region.amazonaws.com/$objectKey');

  // 3. Signer con credenciales *estáticas*
  final signer = AWSSigV4Signer(
    credentialsProvider: AWSCredentialsProvider(
      AWSCredentials(accessKey, secretKey),
    ),
  );

  // 4. Petición sin firmar
  final unsigned = AWSHttpRequest(
    method: AWSHttpMethod.put,
    uri: uri,
    headers: {
      AWSHeaders.host: uri.host,
      AWSHeaders.contentType: 'application/json',
      AWSHeaders.contentLength: bodyBytes.length.toString(),
    },
    body: bodyBytes,
  );

  // 5. Firma (servicio S3, región indicada)
  final AWSSignedRequest signed = await signer.sign(
    unsigned,
    credentialScope: AWSCredentialScope(
      region: region,
      service: AWSService.s3,
    ),
  );

  // 6. Enviar usando los headers firmados
  final response = await http.put(
    uri,
    headers: Map<String, String>.from(signed.headers),
    body: bodyBytes,
  );

  if (response.statusCode == 200) {
    return uri.toString(); // Éxito
  } else {
    throw Exception('S3 error ${response.statusCode}: ${response.body}');
  }
}
// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!
