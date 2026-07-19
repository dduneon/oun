import { Sport } from '@prisma/client';
import { CreateWorkoutDto } from './dto';

/**
 * MVP 검증: HealthKit/Health Connect 미연동이라 manual을 자동 승인하되
 * 명백한 이상치만 걸러낸다. (실 검증 파이프라인은 다음 단계)
 */
export function verifyWorkout(dto: CreateWorkoutDto): {
  status: 'verified' | 'rejected';
  reason?: string;
} {
  const speed = dto.distanceM && dto.durationSec ? dto.distanceM / dto.durationSec : 0; // m/s

  // 사람이 낼 수 없는 속도 → 이동수단 의심.
  if (dto.sport === Sport.running && speed > 8) {
    return { status: 'rejected', reason: '러닝 페이스가 비정상적으로 빨라요' };
  }
  if (dto.sport === Sport.walking && speed > 4) {
    return { status: 'rejected', reason: '걷기 속도가 비정상적으로 빨라요' };
  }
  if (dto.sport === Sport.cycling && speed > 25) {
    return { status: 'rejected', reason: '자전거 속도가 비정상적으로 빨라요' };
  }
  if (dto.steps && dto.steps > 60000) {
    return { status: 'rejected', reason: '걸음 수가 비정상적으로 많아요' };
  }
  return { status: 'verified' };
}
