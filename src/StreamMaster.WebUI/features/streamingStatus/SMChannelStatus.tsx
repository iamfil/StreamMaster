import SMDataTable from '@components/smDataTable/SMDataTable';
import { ColumnMeta } from '@components/smDataTable/types/ColumnMeta';
import { formatJSONDateString, getElapsedTimeString } from '@lib/common/dateTime';
import { ChannelMetric } from '@lib/smAPI/smapiTypes';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';

import { getIconUrl } from '@components/icons/iconUtil';
import CancelChannelDialog from '@components/streaming/CancelChannelDialog';
import { GetChannelMetrics } from '@lib/smAPI/Statistics/StatisticsCommands';
import { StreamInfoDisplay } from './StreamInfoDisplay';
import { VideoInfoDisplay } from './VideoInfoDisplay';

const SMChannelStatus = () => {
  const [sourceChannelMetrics, setSourceChannelMetrics] = useState<ChannelMetric[]>([]);
  const [loading, setLoading] = useState<boolean>(true);

  const channelMetricsRef = useRef<ChannelMetric[]>([]);
  const setChannelMetricsWithRef = (metrics: ChannelMetric[]) => {
    const sourceMetrics = metrics.filter((metric) => metric.SMStreamInfo !== null);
    channelMetricsRef.current = sourceMetrics;
    setSourceChannelMetrics(sourceMetrics);
  };

  const getChannelMetrics = useCallback(async () => {
    try {
      const [channelMetricsData] = await Promise.all([GetChannelMetrics()]);
      setChannelMetricsWithRef(channelMetricsData ?? []);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching channel metrics:', error);
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const fetchData = () => {
      getChannelMetrics();
    };

    fetchData();
    const intervalId = setInterval(fetchData, 2000);

    return () => clearInterval(intervalId);
  }, [getChannelMetrics]);

  const clientBitsPerSecondTemplate = (rowData: ChannelMetric) => {
    const found = channelMetricsRef.current.find((predicate) => predicate.Id === rowData.Id);

    if (found === undefined || found.Metrics.Kbps === undefined) return <div />;
    const kbps = found.Metrics.Kbps;
    const roundedKbps = Math.ceil(kbps);
    return <div>{roundedKbps.toLocaleString('en-US')}</div>;
  };

  const elapsedTSTemplate = useCallback((rowData: ChannelMetric) => {
    return <div className="numeric-field">{getElapsedTimeString(rowData.Metrics.StartTime, new Date().toString(), true)}</div>;
  }, []);

  const actionTemplate = useCallback((rowData: ChannelMetric) => {
    const found = channelMetricsRef.current.find((predicate) => predicate.Id === rowData.Id);
    if (!found) {
      return <div />;
    }

    return (
      <div className="sm-center-stuff">
        <VideoInfoDisplay name={found.Name} videoInfo={found.VideoInfo} />
        <StreamInfoDisplay streamInfo={found.SMStreamInfo!} />
        <CancelChannelDialog channelId={rowData.Id} />
        {/* <MoveToNextStreamDialog channelId={rowData.Id} /> */}
      </div>
    );
  }, []);

  const clientStartTimeTemplate = (rowData: ChannelMetric) => {
    return <div>{formatJSONDateString(rowData.Metrics.StartTime ?? '')}</div>;
  };

  const logoTemplate = useCallback((rowData: ChannelMetric) => {
    const found = channelMetricsRef.current.find((predicate) => predicate.Id === rowData.Id);
    if (!found) {
      return <div />;
    }

    const url = getIconUrl(found.ChannelLogo);
    return (
      <div className="flex icon-button-template justify-content-center align-items-center w-full">
        <img alt={rowData.Name + ' Logo'} src={url} />
      </div>
    );
  }, []);

  const streamingLogoTemplate = useCallback((rowData: ChannelMetric) => {
    const found = channelMetricsRef.current.find((predicate) => predicate.Id === rowData.Id);
    if (!found) {
      return <div />;
    }

    const url = getIconUrl(found.StreamLogo);

    return (
      <div className="flex icon-button-template justify-content-center align-items-center w-full">
        <img alt={rowData.Name + ' Logo'} src={url} />
      </div>
    );
  }, []);

  const averageLatencyTemplate = (rowData: ChannelMetric) => {
    if (rowData.Metrics.AverageLatency === undefined) return <div />;

    const found = channelMetricsRef.current.find((predicate) => predicate.Name === rowData.Name);

    if (found === undefined || found.Metrics === undefined) return <div />;
    return <div>{found.Metrics.AverageLatency.toFixed(2)}</div>;
  };

  const columns = useMemo(
    (): ColumnMeta[] => [
      { bodyTemplate: logoTemplate, field: 'Logo', header: 'C' },
      { bodyTemplate: streamingLogoTemplate, field: 'StreamingLogo', header: 'S' },
      { field: 'Name', filter: true, sortable: true, width: 120 },

      { align: 'center', bodyTemplate: clientStartTimeTemplate, field: 'StartTime', header: 'Start', width: 140 },
      { align: 'right', bodyTemplate: clientBitsPerSecondTemplate, field: 'Metrics.Kbps', header: 'Kbps', width: 70 },
      { align: 'right', bodyTemplate: averageLatencyTemplate, field: 'AverageLatency', header: 'Read ms', width: 60 },
      { align: 'right', bodyTemplate: elapsedTSTemplate, field: 'ElapsedTime', header: '(d hh:mm:ss)', width: 95 },
      { align: 'center', bodyTemplate: actionTemplate, field: 'actions', fieldType: 'actions', header: '', width: 62 }
    ],
    [actionTemplate, elapsedTSTemplate, logoTemplate, streamingLogoTemplate]
  );

  if (loading) return <div>Loading...</div>;

  return <SMDataTable columns={columns} dataSource={sourceChannelMetrics} headerName="CHANNELS" id="channelStatus" />;
};

export default SMChannelStatus;
