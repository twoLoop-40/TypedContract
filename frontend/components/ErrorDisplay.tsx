/**
 * ErrorDisplay.tsx
 *
 * Idris2 컴파일 에러 표시 컴포넌트
 * Spec/ErrorHandling.idr 기반
 */

import React from 'react';

export interface ClassifiedError {
  level: 'syntax' | 'proof' | 'domain' | 'unknown';
  message: string;
  location: string | null;
  suggestion: string;
  available_actions: string[];
  auto_fixable: boolean;
}

interface ErrorDisplayProps {
  error: ClassifiedError | null;
  errorStrategy: string | null;
  onAction: (action: string) => void;
}

const ERROR_EMOJI: Record<string, string> = {
  syntax: '⚠️',
  proof: '🔍',
  domain: '🤔',
  unknown: '❓'
};

const ERROR_LEVEL_LABELS: Record<string, string> = {
  syntax: '문법 에러',
  proof: '증명 실패',
  domain: '도메인 모델링 오류',
  unknown: '알 수 없는 에러'
};

const ACTION_LABELS: Record<string, string> = {
  retry: '자동 수정 재시도',
  fallback: '증명 제거 후 계속',
  reanalyze: '문서 재분석',
  manual: '수동 수정',
  abort: '중단'
};

export default function ErrorDisplay({ error, errorStrategy, onAction }: ErrorDisplayProps) {
  if (!error) {
    return null;
  }

  const emoji = ERROR_EMOJI[error.level] || '❗';
  const levelLabel = ERROR_LEVEL_LABELS[error.level] || error.level;

  // 에러 레벨에 따른 배경색
  const bgColor = {
    syntax: 'bg-yellow-50 border-yellow-300',
    proof: 'bg-blue-50 border-blue-300',
    domain: 'bg-purple-50 border-purple-300',
    unknown: 'bg-gray-50 border-gray-300'
  }[error.level] || 'bg-gray-50 border-gray-300';

  const textColor = {
    syntax: 'text-yellow-800',
    proof: 'text-blue-800',
    domain: 'text-purple-800',
    unknown: 'text-gray-800'
  }[error.level] || 'text-gray-800';

  return (
    <div className={`border-2 rounded-lg p-6 ${bgColor}`}>
      {/* 헤더 */}
      <div className="flex items-center gap-3 mb-4">
        <span className="text-3xl">{emoji}</span>
        <div>
          <h3 className={`text-lg font-bold ${textColor}`}>
            컴파일 중 문제 발생
          </h3>
          <p className="text-sm text-gray-600">
            에러 레벨: <span className="font-semibold">{levelLabel}</span>
          </p>
        </div>
      </div>

      {/* 위치 정보 */}
      {error.location && (
        <div className="mb-3 text-sm font-mono bg-white/50 p-2 rounded">
          <span className="text-gray-600">위치:</span>{' '}
          <span className="font-semibold">{error.location}</span>
        </div>
      )}

      {/* 원인 설명 */}
      <div className="mb-4">
        <h4 className="font-semibold text-sm text-gray-700 mb-2">원인:</h4>
        <p className="text-sm text-gray-800">{error.suggestion}</p>
      </div>

      {/* 자동 수정 불가 경고 */}
      {!error.auto_fixable && (
        <div className="mb-4 p-3 bg-orange-100 border border-orange-300 rounded">
          <p className="text-sm text-orange-800">
            ⚡ 이 에러는 자동 수정이 어렵습니다. 사용자 확인이 필요합니다.
          </p>
        </div>
      )}

      {/* 전략 표시 */}
      {errorStrategy && (
        <div className="mb-4 p-3 bg-white/70 rounded border border-gray-200">
          <p className="text-sm text-gray-700">
            <span className="font-semibold">권장 전략:</span> {errorStrategy}
          </p>
        </div>
      )}

      {/* 에러 메시지 (접을 수 있음) */}
      <details className="mb-4">
        <summary className="cursor-pointer text-sm font-semibold text-gray-700 hover:text-gray-900">
          상세 에러 메시지 보기
        </summary>
        <pre className="mt-2 p-3 bg-gray-900 text-gray-100 text-xs overflow-x-auto rounded">
          {error.message}
        </pre>
      </details>

      {/* 사용 가능한 액션 버튼 */}
      <div className="space-y-2">
        <h4 className="font-semibold text-sm text-gray-700 mb-2">
          사용 가능한 옵션:
        </h4>
        <div className="flex flex-wrap gap-2">
          {error.available_actions.map((action) => {
            const isRecommended =
              (action === 'retry' && error.auto_fixable) ||
              (action === 'fallback' && error.level === 'proof') ||
              (action === 'reanalyze' && error.level === 'domain');

            return (
              <button
                key={action}
                onClick={() => onAction(action)}
                className={`px-4 py-2 rounded font-medium text-sm transition-colors ${
                  isRecommended
                    ? 'bg-blue-600 text-white hover:bg-blue-700'
                    : 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50'
                }`}
              >
                {ACTION_LABELS[action] || action}
                {isRecommended && ' (권장)'}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
