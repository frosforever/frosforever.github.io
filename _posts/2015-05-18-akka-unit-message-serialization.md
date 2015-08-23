---
layout: post
title:  "Serialization of Unit in akka"
date:   2015-05-18 17:49:00
description: "Why one should favor () over Unit with Akka"
---

A common mistake in scala is using `Unit`, the companion object, as its value. The correct value of type `Unit` is `()`. Typically, one can get away with using `Unit` as the value, and

{% highlight scala %}
def unitType: Unit = Unit

def unitValue: Unit = ()
{% endhighlight %}

behave similarly. However, this becomes an issue when serialization[^defaultserializer] comes into play. Take, for example, the following actor[^testcode]:

[^defaultserializer]: Using the default java serializer. Other serializers' behavior is left as an exercise to the reader.
[^testcode]: Code for tests can be found https://github.com/frosforever/akka-unit-messages

{% highlight scala %}
class UnitActor extends Actor {
  override def receive: Receive = {
    case Unit => sender ! "Received Unit Object"
    case () => sender ! "Received Unit value"
  }
}
{% endhighlight %}

This simply returns a string to the sender upon receipt of a message. When run on the same VM, everything behaves as expected:

{% highlight scala %}
class NoSerializableTest extends TestKit(ActorSystem("SerializableTest")) with WordSpecLike with ImplicitSender {

  "ActorSystem without requiring serialization" should {
    val unitActor = TestActorRef[UnitActor]

    "send Unit object" in {
      unitActor ! Unit
      within(1 second){
        expectMsg("Received Unit Object")
      }
    }
    "send unit value" in {
      unitActor ! ()
      within(1 second){
        expectMsg("Received Unit value")
      }
    }
  }
}
{% endhighlight %}

However, if the same actor was used in a distributed system, messages would have to be serialized and `Unit` messages will not be sent across the wire.

{% highlight scala %}
class SerializableTest extends TestKit(ActorSystem("SerializableTest", ConfigFactory.parseString(
  "akka.actor.serialize-messages = on"))) with WordSpecLike with ImplicitSender {

  "ActorSystem with serialization" should {
    val unitActor = TestActorRef[UnitActor]

    "fail to send Unit Object" in {
      unitActor ! Unit
      within(1 second){
        expectNoMsg()
      }
    }
    "send unit value" in {
      unitActor ! ()
      within(1 second){
        expectMsg("Received Unit value")
      }
    }
  }
}
{% endhighlight %}

Note that we have mimicked what would happen when messages are sent between VMs by setting `akka.actor.serialize-messages = on`[^akkasettings]. Using the default java serializer, `()` messages are sent without a problem, but `Unit` messages are dropped with the following error being logged to STDOUT:

[^akkasettings]: http://doc.akka.io/docs/akka/snapshot/scala/serialization.html#Verification

{% highlight scala %}
[ERROR] [05/17/2015 14:37:30.959] [pool-6-thread-3-ScalaTest-running-SerializableTest] [akka://SerializableTest/user/$$a] swallowing exception during message send
java.io.NotSerializableException: No configured serialization-bindings for class [scala.Unit$]
{% endhighlight %}


`Unit` is just a regular companion object and plain objects are not serializable, only `case objects` are.

# Take aways:
* Use `()` as the `Unit` value and not `Unit` itself.
* Turn on `serialize-messages` when testing actor systems that will leave a single VM.
