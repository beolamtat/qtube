using System;
using System.Runtime.InteropServices;

namespace QTube.Windows.Services
{
    public static class SleepPreventionService
    {
        [Flags]
        private enum ExecutionState : uint
        {
            EsAwaymodeRequired = 0x00000040,
            EsContinuous = 0x80000000,
            EsDisplayRequired = 0x00000002,
            EsSystemRequired = 0x00000001
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        private static extern ExecutionState SetThreadExecutionState(ExecutionState esFlags);

        private static bool _isPreventingSleep;
        private static readonly object _lock = new();

        public static void PreventSleep()
        {
            lock (_lock)
            {
                if (!_isPreventingSleep)
                {
                    SetThreadExecutionState(ExecutionState.EsContinuous | ExecutionState.EsSystemRequired | ExecutionState.EsAwaymodeRequired);
                    _isPreventingSleep = true;
                }
            }
        }

        public static void AllowSleep()
        {
            lock (_lock)
            {
                if (_isPreventingSleep)
                {
                    SetThreadExecutionState(ExecutionState.EsContinuous);
                    _isPreventingSleep = false;
                }
            }
        }
    }
}
