# UI variants

UI variants allows your coding agent to propose multiple versions of a page section or UI component, directly on the page you are working on:

<iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/nnwckXZgnmY?si=x2grzQd8uuBjyply" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

To enable UI variants in the Tidewave Toolbar, simply click the "UI Variants" icon in the prompt composer, which will then become active, and describe the variants you want:

<img src="assets/variants.png" alt="UI variants example" width="500px">

> #### UI variants vs design canvas {: .info}
>
> Tidewave also has a feature called [design canvas](design_canvas.md). Use UI variants when you want to try out different variations of a component within an existing page. Use the design canvas when you need to step back and explore different versions at a macro level, explore alternative navigation flows, or when you need to share the artifact with colleagues.

> #### Tidewave IDE {: .info}
>
> When using the Tidewave IDE, the agent already knows about the existence of UI variants, you simply need to ask it to build different UI variants of the selected component.

## How does it work?

The variant system works by instructing the agent to annotate different HTML elements in a page with the `data-tw-container` and `data-tw-variant` attributes. Tidewave automatically teaches your agent how to use those.

Whenever variants are added to a page, Tidewave will show a floating UI at the bottom of the page that lets the user switch and explore variants.

Note that all variants are rendered on the page but only one given variant is shown at a given time. This means variants are great for exploring UI changes and smaller components. If you need to explore whole different pages or navigation flows altogether, using separate `git` branches may be a better fit.

## Tips

Here are some useful tips for making the best of variants:

* You can ask for variations of multiple components in the same page

* Once the floating UI is focused, you can use your keyboard to navigate. Use the up and down arrow to change container, use left and right to swap variants

* You can use the inspector to provide feedback and request changes on a given variant

* Once you are done, tell the agent your choice and ask it to remove the other variants

* Variants can be used to explore different designs but also to visualize different states. For example, if you are building a wizard, you can ask the agent to use variants to outline the different wizard states
