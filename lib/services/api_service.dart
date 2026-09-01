import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/character.dart';

/// Erro de comunicacao com a API, ja traduzido para uma mensagem amigavel.
///
/// Toda a camada de UI (RF09) so precisa mostrar [message]; nenhuma tela
/// conhece codigo HTTP ou `SocketException`.
class ApiException implements Exception {
  const ApiException(this.message, {this.isNotFound = false});

  final String message;
  final bool isNotFound;

  @override
  String toString() => message;
}

/// Camada de acesso a rede (RF01, RF03, RF08).
///
/// Nenhum widget faz `http.get` direto: as telas conversam com este service,
/// que centraliza URL base, timeout, decodificacao e traducao de erros.
class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = 'https://rickandmortyapi.com/api';
  static const Duration _timeout = Duration(seconds: 15);

  /// RF01 - lista paginada do catalogo.
  Future<CharacterPage> fetchCharacters({int page = 1}) async {
    final Map<String, dynamic> json =
        await _getJson('$_baseUrl/character/?page=$page');

    final Map<String, dynamic> info =
        (json['info'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final List<dynamic> results =
        (json['results'] as List<dynamic>?) ?? const <dynamic>[];

    return CharacterPage(
      items: results
          .whereType<Map<String, dynamic>>()
          .map(Character.fromJson)
          .toList(growable: false),
      hasNextPage: info['next'] != null,
      totalCount: (info['count'] as int?) ?? results.length,
    );
  }

  /// RF03 - segunda requisicao: dados completos do item selecionado.
  Future<Character> fetchCharacterById(int id) async {
    final Map<String, dynamic> json = await _getJson('$_baseUrl/character/$id');
    return Character.fromJson(json);
  }

  /// RF03 - terceira informacao complementar: o primeiro episodio em que o
  /// personagem aparece. Serve para mostrar que a tela de detalhes agrega
  /// dados de mais de um endpoint.
  Future<Episode> fetchEpisode(String url) async {
    final Map<String, dynamic> json = await _getJson(url);
    return Episode.fromJson(json);
  }

  /// RF08 - busca pelo nome. Retorna o primeiro resultado encontrado, que e
  /// para onde a tela de busca navega diretamente.
  Future<Character> searchFirstByName(String term) async {
    final String query = Uri.encodeQueryComponent(term.trim());
    if (query.isEmpty) {
      throw const ApiException('Digite um nome para buscar.');
    }

    final Map<String, dynamic> json =
        await _getJson('$_baseUrl/character/?name=$query');
    final List<dynamic> results =
        (json['results'] as List<dynamic>?) ?? const <dynamic>[];

    if (results.isEmpty) {
      throw ApiException(
        'Nenhum personagem encontrado para "$term".',
        isNotFound: true,
      );
    }
    return Character.fromJson(results.first as Map<String, dynamic>);
  }

  /// Ponto unico de I/O: timeout, status code e parse ficam todos aqui.
  Future<Map<String, dynamic>> _getJson(String url) async {
    try {
      final http.Response response =
          await _client.get(Uri.parse(url)).timeout(_timeout);

      if (response.statusCode == 404) {
        throw const ApiException(
          'Nao encontramos esse item no catalogo.',
          isNotFound: true,
        );
      }
      if (response.statusCode >= 500) {
        throw const ApiException(
          'O servidor do catalogo esta fora do ar. Tente novamente em instantes.',
        );
      }
      if (response.statusCode != 200) {
        throw ApiException(
          'Nao foi possivel carregar os dados (codigo ${response.statusCode}).',
        );
      }

      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('A resposta do servidor veio em formato inesperado.');
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException(
        'Sem conexao com a internet. Verifique sua rede e tente de novo.',
      );
    } on TimeoutException {
      throw const ApiException(
        'A conexao demorou demais para responder. Tente novamente.',
      );
    } on FormatException {
      throw const ApiException('Recebemos uma resposta invalida do servidor.');
    } catch (_) {
      throw const ApiException('Ocorreu um erro inesperado ao falar com o servidor.');
    }
  }

  void dispose() => _client.close();
}
