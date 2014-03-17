from sys import argv
import requests

def get_rfc_content_length(num):
    url = "http://tools.ietf.org/html/rfc%s" % str(num)

    try:
        response = requests.get(url)
        if response is None:
            raise NoHandlerError()
        else:
            content_length = int(response.headers['content-length'])
    except requests.exceptions.ConnectionError:
        return None
    except:
        raise
    else:
        return content_length

class NoHandlerError(Exception):
    def __str__(self):
        return repr('No installed handler handles the request')

if __name__ == '__main__':
    print get_rfc_content_length(argv[1])
    
