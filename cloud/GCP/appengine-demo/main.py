#
# stupid demo for GCP AppEngine
#
import webapp2

class HomePage(webapp2.RequestHandler):
    def get(self):
        self.response.headers['Content-Type'] = 'text/plain'
        self.response.write('Hello, World!')

app = webapp2.WSGIApplication([('/', HomePage),], debug=True)
