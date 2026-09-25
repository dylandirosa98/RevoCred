import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:revocred_flutter/core/data/api_app_repository.dart';
import 'package:revocred_flutter/core/models/app_models.dart';

void main() {
  test('real repository follows the Go API contract', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      switch ('${request.method} ${request.url.path}') {
        case 'GET /v1/bootstrap':
          return _jsonResponse({
            'data': {
              'profile': {
                'display_name': 'Test Member',
                'credit_card_strategy': 'S04',
                'goal': 'Earn without overspending',
                'top_spend_categories': ['groceries'],
                'next_application_target': 'Demo Card',
              },
              'catalog': [_catalogCard()],
              'wallet': [
                {
                  'id': '00000000-0000-0000-0000-000000000010',
                  'catalog_card_id': '00000000-0000-0000-0000-000000000001',
                  'status': 'active',
                  'card': _catalogCard(),
                },
              ],
              'latest_recommendations': {
                'run_id': '00000000-0000-0000-0000-000000000020',
                'strategy_code': 'S04',
                'engine_version': 'v1.0.0',
                'dataset_version': 'demo-v1',
                'items': [
                  {
                    'card_id': '00000000-0000-0000-0000-000000000001',
                    'card_name': 'Demo Card',
                    'first_year_estimate_cents': 42000,
                    'ongoing_annual_estimate_cents': 22000,
                    'reasons': ['Matches grocery spending'],
                  },
                ],
              },
              'wallet_metrics': {
                'score': 77,
                'rating': 'Good',
                'additions': 31,
                'penalties': -4,
                'yearly_value': 333,
              },
              'latest_questionnaire': {
                'monthly_category_spend': {'food': 50000},
                'fee_tolerance_cents': 10000,
                'travel_scope': 'both',
                'rewards_goal': 'travel',
                'credit_tier': 'fair',
              },
              'quick_prompts': ['What should I use for groceries?'],
            },
          });
        case 'GET /v1/chat/messages':
          return _jsonResponse({
            'data': [
              {
                'id': '00000000-0000-0000-0000-000000000030',
                'role': 'assistant',
                'content': 'Grounded demo answer.',
                'created_at': '2026-08-10T00:00:00Z',
              },
            ],
          });
        case 'POST /v1/wallet':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['catalog_card_id'], isNotEmpty);
          expect(body['status'], 'active');
          return _jsonResponse({'data': {}}, statusCode: 201);
        case 'DELETE /v1/wallet':
          expect(jsonDecode(request.body), {'wallet_card_id': 'wallet-entry'});
          return http.Response('', 204);
        case 'POST /v1/chat/messages':
          expect(jsonDecode(request.body), {'content': 'Hello'});
          return _jsonResponse({
            'data': [
              {
                'id': 'user-message',
                'role': 'user',
                'content': 'Hello',
                'created_at': '2026-08-10T00:00:00Z',
              },
              {
                'id': 'assistant-message',
                'role': 'assistant',
                'content': 'Hello from REVO.',
                'created_at': '2026-08-10T00:00:01Z',
              },
            ],
          }, statusCode: 201);
        case 'POST /v1/recommendations':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['monthly_category_spend'], {'groceries': 50000});
          expect(body['fee_tolerance_cents'], 10000);
          return _jsonResponse({
            'data': {
              'engine_version': 'v1.0.0',
              'dataset_version': 'demo-v1',
              'items': [
                {
                  'card_id': '00000000-0000-0000-0000-000000000001',
                  'card_name': 'Demo Card',
                  'ongoing_annual_estimate_cents': 22000,
                  'reasons': ['Matches grocery spending'],
                },
              ],
            },
          }, statusCode: 201);
        default:
          return http.Response('not found', 404);
      }
    });
    final repository = ApiAppRepository(
      baseUrl: 'https://api.example.test',
      supabaseClient: null,
      httpClient: client,
      accessTokenProvider: () => 'test-access-token',
      emailProvider: () => 'member@example.test',
    );

    final data = await repository.loadAppData();
    expect(data.profile.name, 'Test Member');
    expect(data.profile.email, 'member@example.test');
    expect(data.wallet.single.isActive, isTrue);
    expect(
      data.wallet.single.walletCardId,
      '00000000-0000-0000-0000-000000000010',
    );
    expect(data.catalog.single.annualFee, r'$95');
    // Real mode must not fabricate a playbook when the server omits it.
    expect(data.playbook, isNull);
    expect(data.roadmap, hasLength(1));
    expect(data.pointsValue, 77);
    expect(data.projectedYearlyValue, 333);
    expect(data.monthlySpend, {'food': 500});
    expect(data.strategyPlan?.code, 'S04');
    expect(data.strategyPlan?.cards.last, 'Sapphire Preferred');
    expect(data.strategyPreferences?.creditTier, 'fair');
    expect(data.messages.single.content, 'Grounded demo answer.');

    await repository.addCard(data.catalog.single.id);
    await repository.removeCard('wallet-entry');
    final reply = await repository.sendMessage('Hello');
    expect(reply.content, 'Hello from REVO.');
    final recommendation = await repository.saveQuestionnaire(
      const QuestionnaireAnswers(
        lifeStage: 'adult',
        existingCardIds: [],
        feeTolerance: 'low',
        travelScope: 'both',
        creditTier: 'good',
        monthlySpend: {'groceries': 500},
        rewardsGoal: 'travel',
      ),
    );
    expect(recommendation?.cardName, 'Demo Card');
    expect(recommendation?.estimatedYearlyValue, 220);
    expect(
      requests.every(
        (request) =>
            request.headers['Authorization'] == 'Bearer test-access-token',
      ),
      isTrue,
    );
  });
}

Map<String, dynamic> _catalogCard() => {
  'id': '00000000-0000-0000-0000-000000000001',
  'slug': 'demo-card',
  'issuer': 'Demo Bank',
  'network': 'Visa',
  'name': 'Demo Card',
  'best_use': 'Groceries',
  'annual_fee_cents': 9500,
  'reward_rates': {'groceries': 3.0, 'other': 1.0},
  'benefits': ['Demo benefit'],
  'transferable_points': true,
};

http.Response _jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json'},
    );
