import { useSelectedItems } from '@lib/redux/hooks/selectedItems';
import { useSelectedSMChannel } from '@lib/redux/hooks/selectedSMChannel';
import { useSelectedSMStream } from '@lib/redux/hooks/selectedSMStream';

const useSelectedSMItems = (key?: string) => {
  const { selectedSMChannel, setSelectedSMChannel } = useSelectedSMChannel(key ?? 'SMChannelDataSelector');
  const { selectedSMStream, setSelectedSMStream } = useSelectedSMStream(key ?? 'SMChannelDataSelector');
  const { selectedItems, setSelectedItems } = useSelectedItems(key ?? 'SMChannelDataSelector');

  return {
    selectedItems,
    selectedSMChannel,
    selectedSMStream,
    setSelectedItems,
    setSelectedSMChannel,
    setSelectedSMStream
  };
};

export default useSelectedSMItems;
