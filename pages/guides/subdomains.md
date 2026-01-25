# Subdomains

Tidewave Web supports applications that run across multiple domains.

If you are using multiple hosts/subdomains during development, you must use a secure domain. This implies you must either:

* Use `*.localhost`. For example, by running your application on localhost, you can access it at `localhost:3000` and `admin.localhost:3000` from most browsers (Safari being a notable exception)

* Use `https`, in those cases, see our [HTTPS](https.md) guide

At the moment, a single Tidewave session cannot navigate across domains, so if you are working on both domains above at the same time, you will need at least two browser tabs running Tidewave. Generally speaking, you have two options to run Tidewave with multiple subdomains:

* Make the domains match, by accessing Tidewave at the same domains as each application. This is the preferred option. In the example above, it means opening Tidewave at `localhost:9832` to access `localhost:3000`, and another Tidewave at `admin.localhost:9832` to access `admin.localhost:3000`. The downside of this approach, however, is that Tidewave will store its settings and chats separately within each domain.

* Run Tidewave at `localhost:9832` on both tabs to access `localhost:9832` and `admin.localhost:9832`. In order for this to work, you will need to configure your framework to use cookies as `SameSite=None; Secure`, which we document below. Note that with this approach, your application storage (`localStorage`, etc) will be separate when accessed within Tidewave and outside of it. 

## Configuring Cookies

To configure your cookies to use `SameSite=None; Secure` across different frameworks, follow the step below. Note this requires you to run your application on a secure host, such as `localhost` and `*.localhost`, or use [HTTPS](https.md).

<!-- tabs-open -->

### Django

Add the following to your `settings.py` (typically in your development settings):

```python
if DEBUG:
    SESSION_COOKIE_SAMESITE = 'None'
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SAMESITE = 'None'
    CSRF_COOKIE_SECURE = True
```

### FastAPI

Configure it directly whenever you set the cookie (remember to apply `SameSite=None` only in development):

```python
response.set_cookie(
    key="your_session",
    value="your_value",
    samesite="none",
    secure=True,
    httponly=True,
)
```

For the session middleware, you might set this:

```python
from starlette.middleware.sessions import SessionMiddleware

app.add_middleware(
    SessionMiddleware,
    secret_key="your-secret-key",
    session_cookie="your_app_session",
    same_site="none",
    https_only=True,
)
```

### Flask

Add the following to your Flask app configuration:

```python
app = Flask(__name__)

if app.debug:
    # Session configuration
    app.config['SESSION_COOKIE_SAMESITE'] = 'None'
    app.config['SESSION_COOKIE_SECURE'] = True
    
    # If using Flask-Login or other extensions, also set:
    app.config['REMEMBER_COOKIE_SAMESITE'] = 'None'
    app.config['REMEMBER_COOKIE_SECURE'] = True
```

### Next.js

Configure it directly whenever you set the cookie (remember to apply `SameSite=None` only in development):

```typescript
response.cookies.set({
  name: 'your-cookie-name',
  value: 'your-value',
  sameSite: (process.env.NODE_ENV === 'development' ? 'none' : 'lax'),
  secure: true,
})
```

### Ruby on Rails

Add the following to `config/initializers/development.rb`:

```ruby
config.session_store :cookie_store,
  key: "__your_app_session",
  same_site: :none,
  secure: true,
  assume_ssl: true
```

And make sure you are using `rack-session` version `2.1.0` or later.

### Phoenix

Open up `lib/your_app_web/endpoint.ex`, find the code block that says `if code_reloading? do`, and then add the following line at the top:

```elixir
if code_reloading? do
  @session_options Keyword.merge(@session_options, same_site: "None", secure: true)
  # here goes the remaining of the code reloading configuration
end
```

<!-- tabs-close -->
