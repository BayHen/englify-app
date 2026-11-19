import { useLocalSearchParams } from 'expo-router';
import { MistakeReviewScreen } from '@/features/learning/mistake-review-screen';
export default function Route() { const { id } = useLocalSearchParams<{ id: string }>(); return <MistakeReviewScreen id={id} />; }
