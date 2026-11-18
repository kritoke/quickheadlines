require "./spec_helper"

class FailingTestActor < Actor
  def_call boom : Int32
  def_call ok : Int32

  def dispatch(message : Message) : Nil
    case message
    when CallBoom then raise "kaboom"
    when CallOk   then message.deliver_reply_json(42.to_json)
    end
  end
end

describe Actor do
  it "fails a def_call immediately when the handler raises" do
    actor = FailingTestActor.new("failing-test")
    actor.start
    started = Time.instant
    expect_raises(ActorCallError, /kaboom/) { actor.boom }
    (Time.instant - started).should be < 5.seconds
    # The actor keeps serving after an error
    actor.ok.should eq(42)
    actor.shutdown
  end
end
