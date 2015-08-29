---
layout: post
title: "Using value classes with Slick"
description: "Using value classes for IDs and other columns in Slick for better type safety"
---

# Introduction

When using Slick, the type system can be leveraged to ensure that IDs won't get mixed up or used incorrectly in a join. The underlying value can still be stored as an `INT` or `VARCHAR` in the DB.

# Set up

Say we have an application that deals with coffees and suppliers. Suppliers can deal with multiple coffees which we will model as a many to many relationship.

{% highlight scala %}
val coffees = TableQuery[Coffees]
val suppliers = TableQuery[Suppliers]
val coffeeSuppliers = TableQuery[CoffeeSuppliers]

case class CoffeeRow(id: Int, name: String, price: Double)

class Coffees(tag: Tag) extends Table[CoffeeRow](tag, "COFFEES") {
  def id = column[Int]("ID", O.PrimaryKey)
  def name = column[String]("COF_NAME")
  def price = column[Double]("PRICE")
  def * = (id, name, price) <> (CoffeeRow.tupled, CoffeeRow.unapply)
}

case class SupplierRow(id: Int, name: String, address: String)

class Suppliers(tag: Tag) extends Table[SupplierRow](tag, "SUPPLIERS") {
  def id = column[Int]("ID", O.PrimaryKey)
  def name = column[String]("SUP_NAME")
  def address = column[String]("ADDRESS")

  def * = (id, name, address) <> (SupplierRow.tupled, SupplierRow.unapply)
}

class CoffeeSuppliers(tag: Tag) extends Table[(Int, Int)](tag, "COFFEE_SUPPLIERS") {
    def coffeeId = column[Int]("COFFEE_ID")
    def supplierId = column[Int]("SUPPLIER_ID")

    def fkCoffee = foreignKey("COF_SUP_COF", coffeeId, coffees)(_.id)
    def fkSupplier = foreignKey("COF_SUP_SUP", supplierId, suppliers)(_.id)
    def * = (coffeeId, supplierId)
}
{% endhighlight %}

We can then query the tables doing something like:

{% highlight scala %}
def findCoffeeBySuppliers(supplierId: Int): Query[Coffees, CoffeeRow, Seq] = {
  for {
    cs <- coffeeSuppliers if cs.supplierId === supplierId
      c <- cs.fkCoffee
  } yield {
    c
  }
}
{% endhighlight %}

While this is a fairly trivial example, we can see the danger in using `Int` as our id type. There's nothing preventing us from writing the above query but matching on `coffeeId` instead.
{% highlight scala %}
def findCoffeeBySuppliers(supplierId: Int): Query[Coffees, CoffeeRow, Seq] = {
  for {
    // Oops! This is not what we intended
    cs <- coffeeSuppliers if cs.coffeeId === supplierId
    c <- cs.fkCoffee
  } yield {
    c
  }
}
{% endhighlight %}

# A better way

Instead, we can leverage the power of value classes and mapped types to have the compiler tell us when things are wrong.
First, create the ID value classes
{% highlight scala %}
case class CoffeeId(id: Int) extends AnyVal
case class SupplierId(id: Int) extends AnyVal
{% endhighlight %}

Discussion on what exactly a value class is, is beyond the scope of this post, but suffice to say that it is a way of wrapping a value type in a different type signature that ideally, the compiler will remove after type checking. This gets us the safety of types, but without the added overhead of boxing.

Now let's rewrite those tables using the value classes:
{% highlight scala %}
val coffees = TableQuery[Coffees]
val suppliers = TableQuery[Suppliers]
val coffeeSuppliers = TableQuery[CoffeeSuppliers]

case class CoffeeRow(id: CoffeeId, name: String, price: Double)

  class Coffees(tag: Tag) extends Table[CoffeeRow](tag, "COFFEES") {
    def id = column[CoffeeId]("ID", O.PrimaryKey)
      def name = column[String]("COF_NAME")
      def price = column[Double]("PRICE")
      def * = (id, name, price) <> (CoffeeRow.tupled, CoffeeRow.unapply)
  }

case class SupplierRow(id: SupplierId, name: String, address: String)

  class Suppliers(tag: Tag) extends Table[SupplierRow](tag, "SUPPLIERS") {
    def id = column[SupplierId]("ID", O.PrimaryKey)
      def name = column[String]("SUP_NAME")
      def address = column[String]("ADDRESS")

      def * = (id, name, address) <> (SupplierRow.tupled, SupplierRow.unapply)
  }

class CoffeeSuppliers(tag: Tag) extends Table[(CoffeeId, SupplierId)](tag, "COFFEE_SUPPLIERS") {
  def coffeeId = column[CoffeeId]("COFFEE_ID")
    def supplierId = column[SupplierId]("SUPPLIER_ID")

    def fkCoffee = foreignKey("COF_SUP_COF", coffeeId, coffees)(_.id)
    def fkSupplier = foreignKey("COF_SUP_SUP", supplierId, suppliers)(_.id)
    def * = (coffeeId, supplierId)
}
{% endhighlight %}

Notice it looks pretty much the same except we're using the id value classes rather than `Int`. `CoffeeSuppliers` no longer has a error prone type of `(Int, Int)` but instead has  the safer and more useful `(CoffeeId, SupplierId)`. There's one more thing that's needed for this to work and that's the slick mapping for the id classes
{% highlight scala %}
implicit val coffeeIdColumnType = MappedColumnType.base[CoffeeId, Int]({i => i.id}, {i => CoffeeId(i)})
implicit val supplierIdColumnType = MappedColumnType.base[SupplierId, Int]({i => i.id}, {i => SupplierId(i)})
{% endhighlight %}

Now if we make a mistake in a query, the compiler will tell us!
{% highlight scala %}
def findCoffeeBySuppliers(supplierId: SupplierId): Query[Coffees, CoffeeRow, Seq] = {
  for {
    // Won't compile!
    cs <- coffeeSuppliers if cs.coffeeId === supplierId
    c <- cs.fkCoffee
  } yield {
    c
  }
}
{% endhighlight %}

This can also be done with other types besides `Int` for example diffrentiating between coffee name and supplier name though both are `String`s.

# Extras

Sometimes, you want to treat the value class as the primitive type or you would have to do a bunch of boxing and unboxing. In those cases you can either cast the column in the query to the type you want, or bring in the column extension methods for the underlying type.
For example, say you have a value class for a `String` that you want to lower cast for use in a query. Normally you would just call `toLowerCase` on the `String`
{% highlight scala %}
coffees.filter(_.name.toLowerCase === "yirgacheffe")
{% endhighlight %}
but once it's wrapped in the value class, `toLowerCase` is no longer available. You can either cast it
{% highlight scala %}
case class Name(name: String) extends AnyVal

coffees.filter(_.name.asColumnOf[String].toLowerCase === "yirgacheffe")
{% endhighlight %}
which will treat it as a string in that query. Or you can bring in all the extension methods that would otherwise be available on `String` columns
{% highlight scala %}
implicit def coffeeNameStringMethods(c: Rep[CoffeeName]): StringColumnExtensionMethods[CoffeeName] =
  new StringColumnExtensionMethods[CoffeeName](c)
{% endhighlight %}
