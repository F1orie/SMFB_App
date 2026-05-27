# FB機能 現状理解 LLM向け

meta:
  workspace: D:\4_26_f\Solution\smfb_app
  target_root: lib/features/fb
  purpose: 大規模修正前の現状把握
  edit_policy: この文書作成時点では実装変更なし
  secret_policy: analysis_config.dart の geminiApiKey 実値は転記禁止
  file_count_under_target_including_ignored_local_config: 19
  note: initial glob-like listing may omit ignored analysis_config.dart, but the file was read and included

target_tree:
  - path: lib/features/fb/application/config/analysis_config.dart
    kind: dart_config
  - path: lib/features/fb/application/config/analysis_config.dart.example
    kind: dart_config_template
  - path: lib/features/fb/application/state/analysis_state.dart
    kind: unused_state_model
  - path: lib/features/fb/application/types/analysis_error_type.dart
    kind: unused_enum
  - path: lib/features/fb/application/types/analysis_params.dart
    kind: unused_params_model
  - path: lib/features/fb/application/types/analysis_status.dart
    kind: unused_enum
  - path: lib/features/fb/application/usecases/analyze_chat_usecase.dart
    kind: unused_usecase
  - path: lib/features/fb/backend/main.py
    kind: unused_python_backend
  - path: lib/features/fb/domain/features/analysis_result.dart
    kind: mostly_unused_domain_model
  - path: lib/features/fb/domain/features/sleep_data.dart
    kind: mock_graph_data_model
  - path: lib/features/fb/domain/types/chat_role.dart
    kind: unused_enum
  - path: lib/features/fb/infrastructure/api/api_client.dart
    kind: active_gemini_client
  - path: lib/features/fb/infrastructure/api/rag_repository.dart
    kind: compatibility_wrapper_unused_by_ui
  - path: lib/features/fb/infrastructure/api/sleep_mock_data.dart
    kind: mock_data_builder
  - path: lib/features/fb/infrastructure/log/app_logger.dart
    kind: active_logger
  - path: lib/features/fb/presentation/dialogs/fb_chat_dialog.dart
    kind: active_chat_ui
  - path: lib/features/fb/presentation/pages/fb_dashboard_page.dart
    kind: active_main_ui
  - path: lib/features/fb/presentation/router/fb_router.dart
    kind: route_definition_not_wired_in_material_app
  - path: lib/features/fb/presentation/theme/fb_colors.dart
    kind: unused_theme_constants

active_entrypoints:
  app_init:
    file: lib/main.dart
    calls:
      - WidgetsFlutterBinding.ensureInitialized()
      - FlutterForegroundTask.initCommunicationPort() when !kIsWeb
      - SleepRepository.instance.init()
      - runApp(const SmfApp())
  fb_tab_mount:
    file: lib/app/main.dart
    widget_path: SmfApp -> MainShell -> IndexedStack -> FbDashboardPage
    index: 4
    params:
      key: ValueKey(_fbRebuildKey)
      targetSession: _fbTargetSession
  navigation_to_fb:
    from_alarm:
      callback: _navigateToFb()
      effect:
        - _fbTargetSession = null
        - _fbRebuildKey++
        - _mainTab.select(4)
    from_list:
      callback: _navigateToFbSession(SleepSession session)
      effect:
        - _fbTargetSession = session
        - _fbRebuildKey++
        - _mainTab.select(4)
        - setState()

active_runtime_flow:
  dashboard_load:
    file: lib/features/fb/presentation/pages/fb_dashboard_page.dart
    class: FbDashboardPage
    state_class: _FbDashboardPageState
    init: initState() -> _loadData()
    session_resolution:
      expression: widget.targetSession ?? SleepRepository.instance.allSessions.last_if_not_empty
      no_session: _session = null; UI shows no data message
    memo_resolution:
      source: SleepRepository.instance.notesForSession(session.id)
      selected: notes.last.memo if notes.isNotEmpty else empty string
      ignored_note_fields:
        - hadAlcohol
        - hadCaffeine
        - didExercise
    normal_advice_resolution_order:
      - static_memory_cache: _adviceCache[session.id]
      - shared_preferences: fb_ai_advice_<sessionId>
      - api_call: _runAiAnalysis(session, memo)
    normal_advice_prompt_inputs:
      - session.startAtEpochMs formatted as HH:mm
      - session.endAtEpochMs formatted as HH:mm or 不明
      - duration computed from end-start or 不明
      - memo or なし
    normal_advice_user_message: 昨夜の睡眠データを分析して、改善のためのアドバイスをください。
    normal_advice_cache_write:
      - _adviceCache[session.id] = advice
      - prefs.setString('fb_ai_advice_<sessionId>', advice)
  special_advice:
    enum: AdviceType { bedding, food, routine }
    method: _fetchSpecialAdvice(SleepSession session, String memo, AdviceType type)
    cache_key: fb_special_<type.name>_<sessionId>
    cache_layer: shared_preferences_only
    prompt_variants:
      bedding: 寝具の具体的な選び方やアプローチを約300文字で提案
      food: 睡眠の質を高める食べ物・飲み物・避けるものを約300文字で提案
      routine: 入眠をスムーズにする夜ルーティンをタイムライン込みで約300文字で提案
    user_message: この睡眠データに基づいた具体的なおすすめ情報を教えてください。
    error_ui_string: アドバイスの取得に失敗しました。再試行してください。
  chat:
    file: lib/features/fb/presentation/dialogs/fb_chat_dialog.dart
    widget: FbChatDialog
    params:
      - SleepSession session
      - String memo
    prefs_key: fb_chat_history_<sessionId>
    message_shape: List<Map<String,String>> where role in user|assistant and content is String
    init: initState() -> _loadHistory()
    send: _sendMessage()
    system_prompt_inputs:
      - session.startAtEpochMs
      - session.endAtEpochMs
      - computed duration
      - memo
    api_history:
      source: _messages.take(_messages.length - 1)
      role_conversion: implemented inside ApiClient; assistant -> model
    success_effects:
      - append user message before API
      - append assistant reply after API
      - _saveHistory()
    failure_effect:
      - append assistant message: 申し訳ありません。エラーが発生しました。もう一度お試しください。
    dispose:
      - _textCtrl.dispose()
      - _scrollCtrl.dispose()

api_client:
  file: lib/features/fb/infrastructure/api/api_client.dart
  class: ApiClient
  model: gemini-2.5-flash
  endpoint: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=<AnalysisConfig.geminiApiKey>
  dependencies:
    - dart:convert
    - package:http/http.dart as http
    - AnalysisConfig
    - AppLogger
  public_methods:
    chat:
      signature: Future<String> chat({required String systemPrompt, required String userMessage, List<Map<String,String>> history = const []})
      request_body:
        system_instruction:
          parts:
            - text: systemPrompt
        contents:
          - history entries converted to Gemini role format
          - current user message
        generationConfig:
          maxOutputTokens: 1500
      role_mapping:
        assistant: model
        user: user
      timeout: 30 seconds
      retry:
        status_503: up to 2 retries with 3 seconds delay
        catch_condition: attempt < 2 && e is! Exception
      success_parse:
        - jsonDecode(utf8.decode(response.bodyBytes)) as Map<String,dynamic>
        - data['candidates'] as List<dynamic>
        - candidates.first['content']
        - content['parts'] as List<dynamic>
        - parts.first['text'] as String
        - _stripMarkdown(raw)
      markdown_strip:
        - remove **bold**
        - remove *italic-like*
        - remove markdown headings pattern #+\s
        - remove inline backticks
      known_parse_risks:
        - candidates missing or empty throws
        - parts missing or empty throws
        - safety/filter response shape may throw
        - non-JSON body in success range would throw
      lifecycle_risk:
        http.Client is never closed

storage_keys:
  fb:
    normal_advice: fb_ai_advice_<sessionId>
    special_advice: fb_special_<type>_<sessionId>
    chat_history: fb_chat_history_<sessionId>
  alarm_repository:
    sessions: sleep_sessions
    epochs: sleep_epochs
    notes: sleep_notes

external_dependencies:
  internal:
    - lib/features/alarm/domain/sleep_session.dart
    - lib/features/alarm/domain/sleep_note.dart
    - lib/features/alarm/domain/sleep_epoch.dart
    - lib/features/alarm/infrastructure/sleep_repository.dart
  packages:
    - flutter/material.dart
    - shared_preferences
    - http
    - dart:developer
    - dart:convert
    - dart:math
  external_services:
    - Google Gemini API via Generative Language API
    - OpenAI API only in unused backend/main.py

alarm_boundary:
  SleepSession:
    fields:
      - id
      - startAtEpochMs
      - endAtEpochMs
      - alarmTimeEpochMs
      - status
      - algoVersion
      - samplingPeriodSec
      - tzOffsetMin
      - appVersion
      - syncState
    fb_used_fields:
      - id
      - startAtEpochMs
      - endAtEpochMs
  SleepNote:
    fields:
      - sessionId
      - createdAtEpochMs
      - memo
      - hadAlcohol
      - hadCaffeine
      - didExercise
    fb_used_fields:
      - memo
    fb_ignored_fields:
      - createdAtEpochMs
      - hadAlcohol
      - hadCaffeine
      - didExercise
  SleepEpoch:
    fields:
      - sessionId
      - tEpochMs
      - activityCount
      - scoreDepth
    fb_used_fields: []
    note: GraphPage uses scoreDepth to build graph points; FB AI prompt currently ignores epochs.

file_details:
  lib/features/fb/application/config/analysis_config.dart:
    symbols:
      - AnalysisConfig.alertThreshold
      - AnalysisConfig.geminiApiKey
    used_by:
      - ApiClient._endpoint
    notes:
      - geminiApiKey is hardcoded in local ignored file.
      - Do not copy key value into docs or prompts.
      - alertThreshold is not observed in current fb flow.
  lib/features/fb/application/config/analysis_config.dart.example:
    symbols:
      - AnalysisConfig.alertThreshold
      - AnalysisConfig.geminiApiKey empty template
    notes:
      - setup comments instruct copy to analysis_config.dart and set Google AI Studio key.
  lib/features/fb/application/state/analysis_state.dart:
    symbols:
      - AnalysisState
    fields:
      - bool isLoading
      - AnalysisResult? result
      - String? errorMessage
    used_by_active_flow: false
  lib/features/fb/application/types/analysis_error_type.dart:
    symbols:
      - AnalysisErrorType.network
      - AnalysisErrorType.timeout
      - AnalysisErrorType.invalidKey
      - AnalysisErrorType.unknown
    used_by_active_flow: false
    stale_comment: Python reference
  lib/features/fb/application/types/analysis_params.dart:
    symbols:
      - AnalysisParams
    fields:
      - query
      - useHistory default true
      - maxTokens default 500
    used_by_active_flow: false
  lib/features/fb/application/types/analysis_status.dart:
    symbols:
      - AnalysisStatus.initial
      - AnalysisStatus.loading
      - AnalysisStatus.success
      - AnalysisStatus.failure
    used_by_active_flow: false
    stale_comment: Python server reference
  lib/features/fb/application/usecases/analyze_chat_usecase.dart:
    symbols:
      - AnalyzeChatUseCase
      - execute(String input)
    dependencies:
      - AnalysisResult
      - RagRepository
    active_ui_reference: false
    behavior:
      - calls RagRepository.fetchAnalysis(input)
      - returns AnalysisResult.fromJson(jsonResponse)
  lib/features/fb/backend/main.py:
    symbols:
      - FastAPI app
      - SleepDataRequest
      - analyze_sleep(req)
    endpoint:
      method: POST
      path: /analyze_sleep
    request_fields:
      - efficiency
      - deep_time
      - awakening_count
      - memo
    ai_model: gpt-4o
    active_dart_reference: false
  lib/features/fb/domain/features/analysis_result.dart:
    symbols:
      - AnalysisResult
      - AnalysisResult.fromJson(Map<String,dynamic>)
    fields:
      - text
      - confidence
      - createdAt
    json_contract:
      text: json['answer'] ?? fallback
      confidence: (json['score'] ?? 0.0).toDouble()
      createdAt: DateTime.now()
    used_by:
      - AnalysisState
      - AnalyzeChatUseCase
    active_ui_reference: false
  lib/features/fb/domain/features/sleep_data.dart:
    symbols:
      - SleepDepthPoint
      - SleepSummaryMock
      - DailySleepDepthMock
    used_by:
      - lib/features/fb/infrastructure/api/sleep_mock_data.dart
      - graph feature through imported mock builder result type
    active_fb_ai_reference: false
  lib/features/fb/domain/types/chat_role.dart:
    symbols:
      - ChatRole.user
      - ChatRole.assistant
    active_reference: false
    replacement_in_active_code: Map<String,String> role values
  lib/features/fb/infrastructure/api/api_client.dart:
    symbols:
      - ApiClient
      - ApiClient.chat
      - ApiClient._stripMarkdown
    active_reference:
      - FbDashboardPage._apiClient
      - FbChatDialog._apiClient
      - RagRepository._apiClient
    see: api_client
  lib/features/fb/infrastructure/api/rag_repository.dart:
    symbols:
      - RagRepository
      - fetchAnalysis(String userInput)
    dependencies:
      - ApiClient
      - AppLogger
    active_ui_reference: false
    note:
      - File comment says direct ApiClient.chat migration completed and class kept for compatibility.
      - Method comment says Claude API but implementation uses Gemini through ApiClient.
  lib/features/fb/infrastructure/api/sleep_mock_data.dart:
    symbols:
      - buildMockDailySleepDepth()
      - _clamp01(double)
    dependencies:
      - dart:math
      - sleep_data.dart
    used_by:
      - lib/features/graph/presentation/graph_page.dart for date 2026-04-21
    active_fb_ai_reference: false
  lib/features/fb/infrastructure/log/app_logger.dart:
    symbols:
      - AppLogger.d(String)
      - AppLogger.e(String,[Object?,StackTrace?])
    dependencies:
      - dart:developer
    used_by:
      - ApiClient
      - RagRepository
  lib/features/fb/presentation/dialogs/fb_chat_dialog.dart:
    symbols:
      - FbChatDialog
      - _FbChatDialogState
      - _DotBlink
    active: true
    dependencies:
      - SleepSession
      - ApiClient
      - SharedPreferences
    risks:
      - jsonDecode(raw) in _loadHistory has no try/catch
      - history unbounded
      - ApiClient direct construction blocks easy test injection
  lib/features/fb/presentation/pages/fb_dashboard_page.dart:
    symbols:
      - AdviceType
      - FbDashboardPage
      - _FbDashboardPageState
    active: true
    dependencies:
      - SleepSession
      - SleepRepository
      - ApiClient
      - SharedPreferences
      - FbChatDialog
    concentrated_responsibilities:
      - session selection
      - memo retrieval
      - prompt construction
      - normal AI advice fetch/cache
      - special advice fetch/cache
      - error state
      - UI rendering
      - chat dialog launching
    risks:
      - large widget with business logic and API logic mixed
      - cache invalidation ignores memo changes
      - ApiClient not injectable
      - only limited sleep data used
  lib/features/fb/presentation/router/fb_router.dart:
    symbols:
      - FbRouter.dashboardPath
      - FbRouter.routes
    route:
      path: /fb_dashboard
      builder: const FbDashboardPage()
    material_app_wiring_observed: false
    note: MainShell directly mounts FbDashboardPage instead.
  lib/features/fb/presentation/theme/fb_colors.dart:
    symbols:
      - FbColors.primaryBlue
      - FbColors.bgGradient
      - FbColors.accentPink
      - FbColors.sleepDeep
      - FbColors.sleepLight
    active_reference_observed: false

unused_or_legacy_clusters:
  legacy_application_layer:
    files:
      - application/state/analysis_state.dart
      - application/types/analysis_error_type.dart
      - application/types/analysis_params.dart
      - application/types/analysis_status.dart
      - application/usecases/analyze_chat_usecase.dart
      - domain/features/analysis_result.dart
      - infrastructure/api/rag_repository.dart
    probable_origin: UseCase/Repository/Domain based design before direct ApiClient.chat migration
    current_status: not used by active dashboard/chat flow
  python_backend:
    file: backend/main.py
    current_status: no Dart reference observed
    mismatch:
      active_app: Gemini direct from Flutter
      backend: OpenAI GPT-4o via FastAPI
  theme_and_router:
    files:
      - presentation/router/fb_router.dart
      - presentation/theme/fb_colors.dart
    current_status: defined but not wired into active UI

known_design_choices:
  state_management:
    active: StatefulWidget + setState + static Map + SharedPreferences
    not_active: Provider/Riverpod/Bloc/Notifier not used in fb
  ai_boundary:
    active: UI directly constructs ApiClient
    alternative_present: AnalyzeChatUseCase -> RagRepository -> ApiClient but inactive
  data_depth:
    active_prompt_uses_basic_session_fields: true
    sleep_epoch_analysis: absent
    note_flags_analysis: absent
  cache_scope:
    normal_advice: session id only
    special_advice: type + session id
    chat_history: session id

risks_for_large_refactor:
  - API key is in local Dart config; avoid committing or documenting actual value.
  - Direct Gemini calls from Flutter expose key in client-side app artifacts.
  - Dashboard owns too many responsibilities.
  - Current prompt ignores available detailed sleep data.
  - Cache invalidation does not account for memo edits or algorithm changes.
  - Chat history may grow without bound.
  - Chat history decode lacks corruption handling.
  - ApiClient response parser assumes candidates/parts/text exist.
  - ApiClient client lifecycle lacks close.
  - Legacy comments mention Python/Claude while active implementation uses Gemini.
  - backend/main.py and active Flutter flow use different AI providers.

recommended_pre_refactor_decisions:
  architecture_direction:
    options:
      - keep_direct_client: formalize FbDashboardPage/FbChatDialog -> ApiClient and delete/archive unused layers
      - restore_layers: UI -> UseCase/State -> Repository -> ApiClient and move prompt/cache logic out of widgets
      - server_proxy: Flutter -> backend -> AI provider; remove client-side API key
  data_contract:
    decide:
      - whether AI analysis should include SleepEpoch.scoreDepth/activityCount
      - whether AI analysis should include SleepNote.hadAlcohol/hadCaffeine/didExercise
      - whether advice cache should be invalidated on memo/note/session changes
  testing_strategy:
    first_step: make ApiClient injectable or abstracted
    test_targets:
      - ApiClient success/error/503/malformed response
      - dashboard no-data state
      - dashboard targetSession selection
      - normal advice cache order
      - special advice cache keys
      - chat history save/load/error

observed_references:
  rg_summary:
    FbDashboardPage:
      - lib/app/main.dart
      - lib/features/fb/presentation/pages/fb_dashboard_page.dart
      - lib/features/fb/presentation/router/fb_router.dart
    FbChatDialog:
      - lib/features/fb/presentation/pages/fb_dashboard_page.dart
      - lib/features/fb/presentation/dialogs/fb_chat_dialog.dart
    RagRepository:
      - lib/features/fb/application/usecases/analyze_chat_usecase.dart
      - lib/features/fb/infrastructure/api/rag_repository.dart
    AnalysisResult:
      - lib/features/fb/application/state/analysis_state.dart
      - lib/features/fb/application/usecases/analyze_chat_usecase.dart
      - lib/features/fb/domain/features/analysis_result.dart
    buildMockDailySleepDepth:
      - lib/features/fb/infrastructure/api/sleep_mock_data.dart
      - lib/features/graph/presentation/graph_page.dart
      - lib/features/graph/daily_sleep_depth_mock.dart
    FbColors:
      - lib/features/fb/presentation/theme/fb_colors.dart only

do_not_forget:
  - docs/rt is ignored by .gitignore in current repo.
  - analysis_config.dart is ignored by .gitignore.
  - If generating public docs, never include the actual Gemini key.
  - The user asked for understanding first; implementation files should not be modified during this step.
