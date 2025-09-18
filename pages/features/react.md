# React Integration

Tidewave Web directly integrates with [React](https://react.dev). We can automatically detect React components on the page, [inspect them](inspector.md), and send their source location to the agent.

At the moment, we only support React running within Phoenix and Rails applications. Support for more frameworks as well as standalone React apps are coming in future releases. [Join our waiting list if you're interested](https://forms.gle/8MeXwGjpBFDeGNQw9).

## Requirements

For Tidewave Web to be capable of changing both your frontend and backend at once, your React application must be located in the same Git repository root as your backend project. Furthermore, if your backend (Rails, Phoenix, etc.) is the one serving your frontend, no further changes are necessary. However, if your frontend and backend are effectively two different servers in development running on different ports, additional configuration in your build tool is necessary. Please see the steps below.

Once set up, to verify it is all working as expected, you can [enable the Inspector on the top right](inspector.md) and then hover page elements defined by React components. By holding the `Ctrl` key (or `Cmd` key on macOS) while the inspector is enabled, a purple overlay will appear with the name of the containing React component. You may also click the element while `Ctrl` (or `Cmd`) are still held and verify Tidewave Web will open up the appropriate React source location. See [the Inspector documentation](inspector.md) to learn more.

## Vite support

If your frontend and backend are served by two different hosts/ports, you must redirect the `/tidewave` path in your frontend to your backend. For example, if you have your backend running on port 4000 and Vite on port 3001, you will need the following proxy configuration:

```javascript
// https://vite.dev/config/
export default defineConfig({
  plugins: [tailwindcss(), react()],
  server: {
    port: 3001, // your frontend port
    proxy: {
      "/tidewave": `http://localhost:4000`
    },
  },
});
```

Tidewave Web will also automatically detect error pages coming from Vite and present you with a tooltip for a one-click fix:

<iframe width="640" height="360" src="https://www.youtube.com/embed/al_VaUWxK9I?si=eCUmP9YdzLa7TtgP" title="Tidewave Web autofix for Vite + React errors" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

If the error appears while Tidewave Web is testing your web application, Tidewave Web automatically feeds the error message and stacktrace to the agent.

## Webpack support

If you're using Webpack as your build tool and your frontend and backend are served on different ports, you'll need to configure a proxy to redirect the `/tidewave` path to your backend server.

Add the following configuration to your `webpack.config.js` (or `webpack.dev.js` if using separate files):

```javascript
module.exports = {
  devServer: {
    port: 3001, // your frontend port
    proxy: [
      {
        context: ['/tidewave'],
        target: 'http://localhost:4000' // your backend port
      }
    ]
  }
};
```

## Parcel support

If you're using Parcel as your build tool and your frontend and backend are served on different ports, you'll need to configure a proxy to redirect the `/tidewave` path to your backend server.

Parcel v2 has built-in API proxy support. Create a `.proxyrc.json` file in your project root:

```json
{
  "/tidewave": {
    "target": "http://localhost:3000"
  }
}
```
