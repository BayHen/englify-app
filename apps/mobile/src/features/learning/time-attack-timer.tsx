import { useEffect, useRef, useState } from 'react';
import { AppText } from '@/ui';
import { remainingServerTime, timeAttackClockLabel, type ServerClock } from './time-attack-clock';
export function TimeAttackTimer({ clock, active, onExpire }: { clock: ServerClock; active: boolean; onExpire: () => void }) {
  const [now, setNow] = useState(() => performance.now()); const lastPoll = useRef(-Infinity);
  useEffect(() => {
    if (!active) return;
    const timer = setInterval(() => {
      const tick = performance.now(); setNow(tick);
      if (remainingServerTime(clock, tick) === 0 && tick - lastPoll.current >= 3000) { lastPoll.current = tick; onExpire(); }
    }, 250);
    return () => clearInterval(timer);
  }, [active, clock, onExpire]);
  const remaining = remainingServerTime(clock, now);
  return <AppText variant="title" tone={remaining <= 15000 ? 'error' : 'primary'} accessibilityLabel={`Time remaining ${timeAttackClockLabel(remaining)}`}>
    {timeAttackClockLabel(remaining)}
  </AppText>;
}
