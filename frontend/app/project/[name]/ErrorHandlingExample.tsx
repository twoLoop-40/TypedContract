/**
 * ErrorHandlingExample.tsx
 *
 * 프로젝트 상세 페이지에서 에러 핸들링을 통합하는 예제
 * 실제 page.tsx에 통합 시 참고
 */

'use client';

import React, { useState, useEffect } from 'react';
import ErrorDisplay from '@/components/ErrorDisplay';
import type { WorkflowStatus, ClassifiedError } from '@/types/workflow';
import { apiClient } from '@/lib/api';

export default function ErrorHandlingExample({ projectName }: { projectName: string }) {
  const [status, setStatus] = useState<WorkflowStatus | null>(null);
  const [loading, setLoading] = useState(true);

  // 상태 폴링
  useEffect(() => {
    const fetchStatus = async () => {
      try {
        const response = await apiClient.get<WorkflowStatus>(`/api/project/${projectName}/status`);
        setStatus(response);
      } catch (error) {
        console.error('Failed to fetch status:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchStatus();
    const interval = setInterval(fetchStatus, 3000); // 3초마다 폴링

    return () => clearInterval(interval);
  }, [projectName]);

  // 사용자 액션 처리
  const handleAction = async (action: string) => {
    console.log(`User selected action: ${action}`);

    try {
      // API 호출: 사용자 액션을 백엔드에 전달
      await apiClient.post(`/api/project/${projectName}/error-action`, {
        action
      });

      // 상태 업데이트
      const updatedStatus = await apiClient.get<WorkflowStatus>(
        `/api/project/${projectName}/status`
      );
      setStatus(updatedStatus);
    } catch (error) {
      console.error('Failed to handle action:', error);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (!status) {
    return (
      <div className="p-4 bg-red-50 border border-red-300 rounded">
        <p className="text-red-800">프로젝트를 불러올 수 없습니다.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* 프로젝트 정보 */}
      <div className="bg-white shadow rounded-lg p-6">
        <h2 className="text-2xl font-bold mb-4">{projectName}</h2>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <p className="text-sm text-gray-600">현재 단계</p>
            <p className="font-semibold">{status.current_phase}</p>
          </div>
          <div>
            <p className="text-sm text-gray-600">진행률</p>
            <div className="w-full bg-gray-200 rounded-full h-2.5 mt-2">
              <div
                className="bg-blue-600 h-2.5 rounded-full transition-all"
                style={{ width: `${status.progress * 100}%` }}
              ></div>
            </div>
            <p className="text-sm text-gray-600 mt-1">
              {Math.round(status.progress * 100)}%
            </p>
          </div>
        </div>
      </div>

      {/* 에러 표시 (있는 경우만) */}
      {status.classified_error && (
        <ErrorDisplay
          error={status.classified_error}
          errorStrategy={status.error_strategy || null}
          onAction={handleAction}
        />
      )}

      {/* 완료 상태 */}
      {status.completed && (
        <div className="bg-green-50 border border-green-300 rounded-lg p-6">
          <div className="flex items-center gap-3">
            <span className="text-3xl">✅</span>
            <div>
              <h3 className="text-lg font-bold text-green-800">생성 완료!</h3>
              <p className="text-sm text-green-700">문서가 성공적으로 생성되었습니다.</p>
            </div>
          </div>
          <button
            className="mt-4 px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700"
            onClick={() => window.location.href = `/api/project/${projectName}/download`}
          >
            PDF 다운로드
          </button>
        </div>
      )}
    </div>
  );
}
