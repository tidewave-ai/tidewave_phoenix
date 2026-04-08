# UI variants

UI variants allows your coding agent to propose multiple versions of a page section or UI component, integrated directly with your web framework:

<iframe width="640" height="360" src="https://www.youtube.com/embed/8px8GdpID74?si=MfHsIGPMS9veQR0H" title="Variants in Tidewave" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

## How does it work?

The variant system works by instructing the agent to annotate different HTML elements in a page with the `data-tw-container` and `data-tw-variant` attributes. Tidewave automatically teaches your agent how to use those.

Whenever variants are added to a page, Tidewave will show a floating UI at the bottom of the page that lets the user switch and explore variants.

Note that all variants are rendered on the page but only one given variant is shown at a given time. This means variant are great for exploring UI changes and smaller components. If you need to explore whole different pages or navigation flows altogether, using separate `git` branches may be a better fit.

## Tips

Here are some useful tips for making the best of variants:

* You can ask for variations of multiple components in the same page

* Once the floating UI is focused, you can use your keyboard to navigate. Use the up and down arrow to change container, use left and right to swap variants

* You can use the inspector to provide feedback and request changes on a given variant

* Once you are done, tell the agent your choice and ask it to remove the other variants

* Variants can be used to explore different designs but also to visualize different states. For example, if you are building a wizard, you can ask the agent to use variants to outline the different wizard states
