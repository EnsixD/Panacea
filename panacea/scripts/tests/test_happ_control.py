import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('happ_control', Path(__file__).parents[1] / 'happ_control.py')
happ = importlib.util.module_from_spec(spec)
spec.loader.exec_module(happ)


def layout(label, enabled=True):
    return [0, {}, [{'type': '(ia{sv}av)', 'data': [17, {
        'label': {'type': 's', 'data': label},
        'enabled': {'type': 'b', 'data': enabled}}, []]}]]


class HappControlTests(unittest.TestCase):
    def test_state_comes_from_available_action(self):
        self.assertEqual(happ.menu_state(':1.1', '/MenuBar', layout('Disconnect'))['clientState'], 'connected')
        self.assertEqual(happ.menu_state(':1.1', '/MenuBar', layout('Подключить'))['clientState'], 'disconnected')
        self.assertEqual(happ.menu_state(':1.1', '/MenuBar', layout('Connect', False))['clientState'], 'busy')

    def test_connect_waits_for_confirmation(self):
        off = {'clientState': 'disconnected', '_owner': ':1.1', '_menu': '/MenuBar', '_actions': {'up': 17}}
        with patch.object(happ, 'status', side_effect=[off, {'clientState': 'busy'}, {'clientState': 'connected'}]), patch.object(happ, 'bus') as bus, patch.object(happ.time, 'sleep') as sleep:
            result = happ.toggle()
            self.assertEqual(result, {'ok': True, 'action': 'up', 'clientState': 'connected'})
            self.assertEqual(bus.call_args.args[:8], ('call', ':1.1', '/MenuBar', 'com.canonical.dbusmenu', 'Event', 'isvu', '17', 'clicked'))
            sleep.assert_called_once_with(0.15)

    def test_disconnect_uses_current_menu_action(self):
        on = {'clientState': 'connected', '_owner': ':1.2', '_menu': '/MenuBar', '_actions': {'down': 84}}
        with patch.object(happ, 'status', side_effect=[on, {'clientState': 'disconnected'}]), patch.object(happ, 'bus') as bus:
            result = happ.toggle()
            self.assertEqual(result['action'], 'down')
            self.assertEqual(bus.call_args.args[6], '84')

    def test_unavailable_client_never_receives_command(self):
        with patch.object(happ, 'status', return_value={'clientState': 'unavailable'}), patch.object(happ, 'bus') as bus:
            with self.assertRaises(ValueError): happ.toggle()
            bus.assert_not_called()

    def test_timeout_never_reports_success(self):
        off = {'clientState': 'disconnected', '_owner': ':1.1', '_menu': '/MenuBar', '_actions': {'up': 17}}
        with patch.object(happ, 'status', return_value=off), patch.object(happ, 'bus'), patch.object(happ.time, 'monotonic', side_effect=[0, 31]):
            with self.assertRaises(TimeoutError): happ.toggle()

    def test_public_state_excludes_control_metadata(self):
        self.assertEqual(happ.public({'clientState': 'connected', '_owner': ':1.1'}), {'clientState': 'connected'})


if __name__ == '__main__': unittest.main()
