from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timezone
from statistics import mean
from typing import Any


def summarize_sleep_data(sleep_data: dict[str, Any], sleep_data_source: str) -> str:
    sessions = list(sleep_data.get("sessions") or [])
    epochs = list(sleep_data.get("epochs") or [])
    notes = list(sleep_data.get("notes") or [])
    target_session_id = sleep_data.get("target_session_id")

    if not sessions:
        return f"睡眠データはありません。データソース: {sleep_data_source}"

    sessions.sort(key=lambda item: int(item.get("startAtEpochMs") or 0))
    target = _resolve_target_session(sessions, target_session_id)
    target_id = target.get("id")
    epochs_by_session = _group_by(epochs, "sessionId")
    notes_by_session = _group_by(notes, "sessionId")

    lines = [
        f"データソース: {sleep_data_source}",
        f"対象セッション: {_session_summary(target)}",
        _epoch_summary(epochs_by_session.get(target_id, [])),
        _note_summary(notes_by_session.get(target_id, [])),
    ]

    if len(sessions) > 1:
        lines.append(_recent_trend_summary(sessions, epochs_by_session))

    return "\n".join(line for line in lines if line)


def _resolve_target_session(
    sessions: list[dict[str, Any]], target_session_id: str | None
) -> dict[str, Any]:
    if target_session_id:
        for session in sessions:
            if session.get("id") == target_session_id:
                return session
    return sessions[-1]


def _session_summary(session: dict[str, Any]) -> str:
    start_ms = _as_int(session.get("startAtEpochMs"))
    end_ms = _as_int(session.get("endAtEpochMs"))
    alarm_ms = _as_int(session.get("alarmTimeEpochMs"))
    onset_ms = _as_int(session.get("sleepOnsetEpochMs"))
    duration = "計測中または不明"
    if start_ms is not None and end_ms is not None:
        duration_min = max(0, (end_ms - start_ms) // 60000)
        duration = f"{duration_min // 60}時間{duration_min % 60}分"

    onset_latency = "不明"
    if start_ms is not None and onset_ms is not None and onset_ms >= start_ms:
        latency_min = (onset_ms - start_ms) // 60000
        onset_latency = f"{latency_min}分"

    return (
        f"開始={_format_epoch_ms(start_ms)}, 終了={_format_epoch_ms(end_ms)}, "
        f"アラーム={_format_epoch_ms(alarm_ms)}, 睡眠時間={duration}, "
        f"入眠={_format_epoch_ms(onset_ms)}, 入眠潜時={onset_latency}, "
        f"状態={session.get('status', '不明')}"
    )


def _epoch_summary(epochs: list[dict[str, Any]]) -> str:
    if not epochs:
        return "睡眠深度データ: なし"

    depth_values = [_as_float(epoch.get("scoreDepth")) for epoch in epochs]
    activity_values = [_as_float(epoch.get("activityCount")) for epoch in epochs]
    depth_values = [value for value in depth_values if value is not None]
    activity_values = [value for value in activity_values if value is not None]

    if not depth_values:
        return f"睡眠深度データ: {len(epochs)}件"

    deep_ratio = sum(1 for value in depth_values if value >= 0.8) / len(depth_values)
    shallow_ratio = sum(1 for value in depth_values if value <= 0.5) / len(depth_values)
    awake_ratio = sum(1 for value in depth_values if value < 0.3) / len(depth_values)
    avg_activity = mean(activity_values) if activity_values else 0.0
    avg_depth = mean(depth_values)
    findings = _quality_findings(
        avg_depth=avg_depth,
        deep_ratio=deep_ratio,
        shallow_ratio=shallow_ratio,
        awake_ratio=awake_ratio,
        avg_activity=avg_activity,
    )
    return (
        "睡眠深度データ: "
        f"{len(epochs)}件, 平均深度={avg_depth:.2f}, "
        f"深い睡眠比率={deep_ratio:.0%}, 浅い睡眠比率={shallow_ratio:.0%}, "
        f"中途覚醒相当比率={awake_ratio:.0%}, 平均体動={avg_activity:.2f}, "
        f"所見={findings}"
    )


def _quality_findings(
    *,
    avg_depth: float,
    deep_ratio: float,
    shallow_ratio: float,
    awake_ratio: float,
    avg_activity: float,
) -> str:
    findings = []
    if avg_depth < 0.6 and shallow_ratio >= 0.5:
        findings.append("睡眠時間に対して浅い睡眠が多い")
    if deep_ratio < 0.2:
        findings.append("深い睡眠が少ない")
    if awake_ratio >= 0.1:
        findings.append("中途覚醒相当の区間が目立つ")
    if avg_activity >= 0.5:
        findings.append("体動が多め")
    return "、".join(findings) if findings else "大きな乱れは少ない"


def _note_summary(notes: list[dict[str, Any]]) -> str:
    if not notes:
        return "ライフスタイル記録: なし"

    latest = sorted(notes, key=lambda item: int(item.get("createdAtEpochMs") or 0))[-1]
    flags = []
    if latest.get("hadAlcohol"):
        flags.append("飲酒あり")
    if latest.get("hadCaffeine"):
        flags.append("カフェインあり")
    if latest.get("didExercise"):
        flags.append("運動あり")
    flag_text = "、".join(flags) if flags else "特記事項なし"
    memo = latest.get("memo") or "なし"
    return f"ライフスタイル記録: {flag_text}, メモ={memo}"


def _recent_trend_summary(
    sessions: list[dict[str, Any]],
    epochs_by_session: dict[str, list[dict[str, Any]]],
) -> str:
    durations = []
    quality_points = []
    for session in sessions:
        start_ms = _as_int(session.get("startAtEpochMs"))
        end_ms = _as_int(session.get("endAtEpochMs"))
        if start_ms is not None and end_ms is not None and end_ms >= start_ms:
            durations.append((end_ms - start_ms) / 60000)

        session_id = session.get("id")
        depth_values = [
            value
            for value in (
                _as_float(epoch.get("scoreDepth"))
                for epoch in epochs_by_session.get(str(session_id), [])
            )
            if value is not None
        ]
        if depth_values:
            quality_points.append(
                {
                    "avg_depth": mean(depth_values),
                    "shallow_ratio": sum(1 for value in depth_values if value <= 0.5)
                    / len(depth_values),
                }
            )

    if not durations:
        return f"直近傾向: {len(sessions)}セッション分、睡眠時間は不明"

    avg_min = mean(durations)
    quality_trend = "睡眠深度変化=判断材料不足"
    if len(quality_points) >= 2:
        previous = quality_points[-2]
        latest = quality_points[-1]
        depth_delta = latest["avg_depth"] - previous["avg_depth"]
        shallow_delta = latest["shallow_ratio"] - previous["shallow_ratio"]
        if depth_delta >= 0.05 and shallow_delta <= 0.05:
            quality_trend = "睡眠深度変化=良くなっている"
        elif depth_delta <= -0.05 or shallow_delta >= 0.10:
            quality_trend = "睡眠深度変化=悪くなっている"
        else:
            quality_trend = "睡眠深度変化=横ばい"
        quality_trend += (
            f"（前回平均深度={previous['avg_depth']:.2f}, "
            f"今回平均深度={latest['avg_depth']:.2f}, "
            f"今回浅い睡眠比率={latest['shallow_ratio']:.0%}）"
        )

    return (
        f"直近傾向: {len(sessions)}セッション分, "
        f"平均睡眠時間={int(avg_min) // 60}時間{int(avg_min) % 60}分, "
        f"{quality_trend}"
    )


def _group_by(items: list[dict[str, Any]], key: str) -> dict[str, list[dict[str, Any]]]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in items:
        value = item.get(key)
        if value is not None:
            grouped[str(value)].append(item)
    return grouped


def _format_epoch_ms(value: int | None) -> str:
    if value is None:
        return "不明"
    return datetime.fromtimestamp(value / 1000, tz=timezone.utc).astimezone().strftime(
        "%Y-%m-%d %H:%M"
    )


def _as_int(value: Any) -> int | None:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _as_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None
