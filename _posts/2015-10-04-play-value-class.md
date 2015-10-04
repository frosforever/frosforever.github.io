---
layout: post
title: "Using value classes with Play"
description: "Using value classes for IDs and other columns in Play for better type safety"
---

# Introduction

Continuing in the vein of the previous [post]({% post_url 2015-08-29-slick-value-classes%}), one can bring the type safety all the way out to the web endpoint using Play Binders.

The ultimate goal is to do away with using `Int` as an ID and leverage the compiler everywhere in our application. In other words we want our `routes` file to look like:

{% highlight scala %}
...
GET   /coffee/:id    controllers.Application.coffee(id: CoffeeId)
...
{% endhighlight %}

rather than

{% highlight scala %}
...
GET   /coffee/:id    controllers.Application.coffee(id: Int)
...
{% endhighlight %}

# Set up

Contiuning with the previous example,

{% highlight scala %}
case class CoffeeId(id: Int) extends AnyVal
{% endhighlight %}

We can then add a play binder as follows

{% highlight scala %}
import play.api.mvc.PathBindable

object Binders {

  implicit def coffeeIdPathBinder(implicit intBinder: PathBindable[Int]) = new PathBindable[CoffeeId] {
    override def bind(key: String, value: String): Either[String, CoffeeId] = {
      intBinder.bind(key, value).right.map(CoffeeId)
    }
    override def unbind(key: String, coffeeId: CoffeeId): String = {
      intBinder.unbind(key, coffeeId.id)
    }
  }

}
{% endhighlight %}

One more step is needed to tell Play where to look for the binders. Add the following to `build.sbt`:

{% highlight scala %}
lazy val root = (project in file(".")).enablePlugins(PlayScala).settings(
  routesImport += "Binders._"
)
{% endhighlight %}

Combined with the `MappedColumn` in slick seen in the last post, we can have `Id` type safety from both sides of the application. From the REST endpoint to the persistance layer. No more plain `Int`s to get confused between, the compiler will help you out.

# Notes

Though `build.sbt` and the `route` file referenced `CoffeeId`, that's only if `CoffeeId` is part of the default package. If it's anywhere else you might have to fully specify the package name. That is, `com.foo.bar.Binders._` in `build.sbt`. Or `controllers.Application.coffee(id: com.foo.bar.CoffeeId)` in the `routes` file.
