from MonkeyPatchT1 import *
import unittest

class TestNetworkException(unittest.TestCase):

    def test_NoHandler(self):

        real_get = requests.get
       
        requests.get = lambda *args, **kwargs: None

        self.assertRaises(NoHandlerError, get_rfc_content_length, 2549)
    
        requests.get = real_get

    def test_RFC1234(self):

        self.assertEqual(6688, get_rfc_content_length(1234))

    def test_DeterminedLength(self):
        
        real_get = requests.get
    
        def fake_get(url):
            response = real_get(url)
            response.headers['content-length'] = '1024'
            return response
    
        requests.get = fake_get
    
        self.assertEqual(1024, get_rfc_content_length(2549))
        
        requests.get = real_get

if __name__ == "__main__":
    unittest.main()
