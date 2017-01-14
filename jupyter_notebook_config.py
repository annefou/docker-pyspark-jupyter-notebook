# See http://ipython.org/ipython-doc/1/interactive/public_server.html for more information.
# Configuration file for ipython-notebook.
import os

c = get_config()
c.NotebookApp.ip = '0.0.0.0'
c.NotebookApp.port = 8888
c.NotebookApp.open_browser = False
c.NotebookApp.profile = u'default'
c.IPKernelApp.matplotlib = 'inline'

headers = {
    'X-Frame-Options': 'ALLOWALL',
        'Content-Security-Policy': """
            default-src 'self' %(CORS_ORIGIN)s; 
            img-src 'self' %(CORS_ORIGIN)s;
            connect-src 'self' %(WS_CORS_ORIGIN)s;
            style-src 'unsafe-inline' 'self' %(CORS_ORIGIN)s;
            script-src 'unsafe-inline' 'self' %(CORS_ORIGIN)s;
        """ % {'CORS_ORIGIN': os.environ['CORS_ORIGIN'], 'WS_CORS_ORIGIN': 'ws://%s' % os.environ['CORS_ORIGIN'].split('://')[1]}
}

c.NotebookApp.allow_origin = '*'
c.NotebookApp.allow_credentials = True

c.NotebookApp.base_url = '%s/ipython/' % os.environ.get('PROXY_PREFIX', '')
c.NotebookApp.tornado_settings = {
    'static_url_prefix': '%s/ipython/static/' % os.environ.get('PROXY_PREFIX', '')
}

#AF
c.NotebookApp.token = ''
#END AF
if os.environ.get('NOTEBOOK_PASSWORD', 'none') != 'none':
    c.NotebookApp.password = os.environ['NOTEBOOK_PASSWORD']
    del os.environ['NOTEBOOK_PASSWORD']

if os.environ.get('CORS_ORIGIN', 'none') != 'none':
    c.NotebookApp.allow_origin = os.environ['CORS_ORIGIN']

c.NotebookApp.tornado_settings['headers'] = headers
