import { ColumnMeta } from '@components/smDataTable/types/ColumnMeta';
import { UpdateOutputProfile } from '@lib/smAPI/Profiles/ProfilesCommands';
import { OutputProfileDto, UpdateOutputProfileRequest } from '@lib/smAPI/smapiTypes';
import { Checkbox } from 'primereact/checkbox';
import { useCallback } from 'react';
import { OutputProfileColumnConfigProps } from './useOutputProfileColumnConfig';

export const useOutputProfileGroupTitleColumnConfig = (props?: OutputProfileColumnConfigProps) => {
  const update = useCallback((request: UpdateOutputProfileRequest) => {
    UpdateOutputProfile(request)
      .then((res) => {})
      .catch((error) => {
        console.log('error', error);
      })
      .finally();
  }, []);

  const bodyTemplate = useCallback(
    (outputProfileDto: OutputProfileDto) => {
      const disabled = outputProfileDto.IsReadOnly === true || outputProfileDto.ProfileName.toLowerCase() === 'default' ? 'p-disabled' : '';
      return (
        <div className={'flex w-full justify-content-center align-content-center ' + disabled}>
          <Checkbox
            checked={outputProfileDto.EnableGroupTitle}
            onChange={(e) => {
              const outputProfile = { EnableGroupTitle: e.checked, ProfileName: outputProfileDto.ProfileName } as UpdateOutputProfileRequest;
              update(outputProfile);
            }}
          />
        </div>
      );
    },
    [update]
  );

  const columnConfig: ColumnMeta = {
    align: 'left',
    bodyTemplate: bodyTemplate,
    field: 'EnableGroupTitle',
    header: 'Group Title',
    width: 30
  };

  return columnConfig;
};
