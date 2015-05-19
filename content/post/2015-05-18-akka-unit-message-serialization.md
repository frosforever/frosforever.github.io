+++
date = "2015-05-18T17:49:00-04:00"
title = "Serialization of Unit in akka"
description = "Why one should favor () over Unit with Akka"

+++

A common mistake in scala is using `Unit`, the companion object, as its value. The correct value of type `Unit` is `()`. Typically, one can get away with using `Unit` as the value, and

```scala
def unitType: Unit = Unit

def unitValue: Unit = ()
```

behave similarly. However, this becomes an issue when serialization<sup>[1](#myfootnote1)</sup> comes into play. Take, for example, the following actor<sup>[2](#myfootnote2)</sup>:

```scala
class UnitActor extends Actor {
  override def receive: Receive = {
    case Unit => sender ! "Received Unit Object"
    case () => sender ! "Received Unit value"
  }
}
```

This simply returns a string to the sender upon receipt of a message. When run on the same VM, everything behaves as expected:

```scala
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
```

However, if the same actor was used in a distributed system, messages would have to be serialized and `Unit` messages will not be sent across the wire.

```scala
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
```

Note that we have mimicked what would happen when messages are sent between VMs by setting `akka.actor.serialize-messages = on`<sup>[3](#myfootnote3)</sup>. Using the default java serializer, `()` messages are sent without a problem, but `Unit` messages are dropped with the following error being logged to STDOUT:

```
[ERROR] [05/17/2015 14:37:30.959] [pool-6-thread-3-ScalaTest-running-SerializableTest] [akka://SerializableTest/user/$$a] swallowing exception during message send
java.io.NotSerializableException: No configured serialization-bindings for class [scala.Unit$]
```

`Unit` is just a regular companion object and plain objects are not serializable, only `case objects` are.

# Take aways:
* Use `()` as the `Unit` value and not `Unit` itself.
* Turn on `serialize-messages` when testing actor systems that will leave a single VM.

# Footnotes:
<a name="myfootnote1">1</a>: Using the default java serializer. Other serializers' behavior is left as an exercise to the reader.<br>
<a name="myfootnote2">2</a>: Code for tests can be found https://github.com/frosforever/akka-unit-messages<br>
<a name="myfootnote3">3</a>: http://doc.akka.io/docs/akka/snapshot/scala/serialization.html#Verification <br>
