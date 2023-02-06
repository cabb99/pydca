import unittest

class ImportTestCase(unittest.TestCase):
    """Tests that the pydca.plmdca.PlmDCA module is imported correctly
        
    This test verifies that the pydca module can be imported without any errors 
    and that the submodule `plmdca` and its class `PlmDCA` are defined within the module.
    """

    def test_import_plmdca(self):
        """Test that the pydca.plmdca.PlmDCA is imported correctly"""
        try:
            import pydca
        except ImportError:
            self.fail("pydca module was not imported correctly")
        else:
            self.assertTrue(hasattr(pydca, 'plmdca'), "pydca module was imported but plmdca is not defined")
            self.assertTrue(hasattr(pydca.plmdca, 'PlmDCA'), "Modulpydca modulee was imported but plmdca.PlmDCA is not defined")

if __name__ == '__main__':
    unittest.main()