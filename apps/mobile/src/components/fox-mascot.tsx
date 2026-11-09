import { View } from 'react-native';

/** Original geometric fox explorer; no external image or copyrighted asset. */
export function FoxMascot({ size = 114 }: { size?: number }) {
  const unit = size / 114;
  const px = (value: number) => value * unit;
  return <View accessibilityLabel="Englify Quest fox explorer" accessibilityRole="image" style={{ width: size, height: size, alignItems: 'center', justifyContent: 'flex-end' }}>
    <View style={{ position: 'absolute', top: px(8), left: px(17), width: px(33), height: px(33), transform: [{ rotate: '24deg' }], borderRadius: px(6), backgroundColor: '#F7A947' }} />
    <View style={{ position: 'absolute', top: px(8), right: px(17), width: px(33), height: px(33), transform: [{ rotate: '66deg' }], borderRadius: px(6), backgroundColor: '#F7A947' }} />
    <View style={{ width: px(94), height: px(82), borderRadius: px(39), backgroundColor: '#F7A947', alignItems: 'center', justifyContent: 'flex-end', overflow: 'hidden' }}>
      <View style={{ width: px(80), height: px(43), borderTopLeftRadius: px(38), borderTopRightRadius: px(38), backgroundColor: '#FFF5DF', alignItems: 'center' }}>
        <View style={{ width: px(10), height: px(8), borderRadius: px(5), backgroundColor: '#302342', marginTop: px(13) }} />
      </View>
      <View style={{ position: 'absolute', top: px(29), left: px(24), width: px(7), height: px(10), borderRadius: px(4), backgroundColor: '#302342' }} />
      <View style={{ position: 'absolute', top: px(29), right: px(24), width: px(7), height: px(10), borderRadius: px(4), backgroundColor: '#302342' }} />
      <View style={{ position: 'absolute', bottom: px(7), right: px(7), width: px(18), height: px(26), borderRadius: px(8), backgroundColor: '#7456F1', borderWidth: px(2), borderColor: '#FFF5DF' }} />
    </View>
  </View>;
}
