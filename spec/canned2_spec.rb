require 'spec_helper'
require 'platanus/canned2'

describe Platanus::Canned2 do

  class DummyUsr

    attr_reader :char1
    attr_reader :char2

    def initialize(_char1=nil, _char2=nil)
      @char1 = _char1
      @char2 = _char2
    end
  end

  class DummyCtx

    attr_reader :params
    attr_reader :current_user

    def initialize(_user, _params={})
      @current_user = _user
      @params = _params
    end
  end

  class Roles
    include Platanus::Canned2::Definition

    test :test1 do
      true
    end

    profile :user, matcher: :equals_int do

      # Simple allows
      allow 'rute1#action1'
      allow 'rute1#action2', upon(:current_user) { same(:char1) }
      allow 'rute1#action3', upon { same(:char1, key: "current_user.char1") }
      allow 'rute1#action4', upon(:current_user) { same(:param2, key: "char2") and checks(:test1) }
      allow 'rute1#action5', upon(:current_user) { passes { current_user.char2 == params[:param2] } }

      # Complex routes
      allow 'rute1#action5' do
        upon(:current_user) { same(:char1) }
        upon(:current_user) { same(:param2, value: 55) or checks(:test1) }
      end
    end
  end

  let(:good_ctx) { DummyCtx.new(DummyUsr.new(10, "200"), char1: '10', param2: '200') }
  let(:bad_ctx) { DummyCtx.new(DummyUsr.new(10, 30), char1: '10', param2: '200') }

  describe "._run" do
    context 'when using single context rules' do

      it "does authorize on empty rute" do
        Roles.can?(good_ctx, :user, 'rute1#action1').should be_true
      end
      it "does authorize on rute with context and match" do
        Roles.can?(good_ctx, :user, 'rute1#action2').should be_true
      end
      it "does authorize on rute without context and match" do
        Roles.can?(good_ctx, :user, 'rute1#action3').should be_true
      end
      it "does authorize on rute with context, match and test" do
        Roles.can?(good_ctx, :user, 'rute1#action4').should be_true
      end
      it "does not authorize on rute with context, match and test with bad credentials" do
        Roles.can?(bad_ctx, :user, 'rute1#action4').should be_false
      end
      it "does authorize on rute with context and inline test" do
        Roles.can?(good_ctx, :user, 'rute1#action5').should be_true
      end
    end

    context 'when using multiple context rules' do
      it "does authorize on rute with context, match and test" do
        Roles.can?(good_ctx, :user, 'rute1#action5').should be_true
      end
    end
  end

  describe "canned_setup" do
  end
end