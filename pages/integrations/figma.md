# Figma Dev Mode

Tidewave Web supports direct integration with Figma Dev Mode, allowing you to attach Figma Selections to your prompts.

## Configuration

To enable this feature, you will need to:

1. Install the [Figma Desktop](https://www.figma.com/downloads/) app
2. Create or open a Figma Design file within the app
3. Enable the local MCP server following [Figma's official instructions](https://www.youtube.com/watch?v=Cq-7lFMNESk)
4. Back in Tidewave Web, open up Settings, click on Integrations, and enable the Figma integration

Now, whenever you select a frame or layer on Figma, you can click the Attachment icon on Tidewave's chatbox to attach your selection to your prompt.

## FAQ

#### Attaching a Figma Selection fails with reason: "Multiple nodes selected"

Figma only allows a single node to be attached at a given moment. You can either select them, one by one, or create a frame/layer with all desired nodes included.
