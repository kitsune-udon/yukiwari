module Yukiwari::ISet
  APP = Yukiwari

  [
    [
      :HALT,
      APP::Inst["HALT", lambda{|m|
        m.running = false
      }]
    ],

    [
      :CALL,
      lambda{|id|
        s = "CALL (%s)" % [APP::Helper.to_string(id)]
        APP::Inst[s, lambda{|m|
          key = [id, m.cursor]
          if m.leftrec?(id)
            m.call_count[key] ||= 0
            if m.call_count[key] > 0
              if v = m.memo[key]
                m_ret, m_cur, m_r = v
                m.return_value = m_ret
                m.cursor = m_cur
                m.call_stack[-1][3] += m_r
                m.incl
              else
                m.return_value = false
                m.incl
              end
            else
              m.call_stack.push([m.ip+1,id,m.cursor,[]])
              m.ip = APP::Label[id]
              m.call_count[key] += 1
            end
          else
            if v = m.memo[key]
              m_ret, m_cur, m_r = v
              action_results = m.call_stack[-1][3]
              action_results += m_r
              m.return_value = m_ret
              m.incl
              m.cursor = m_cur
            else
              m.call_stack.push([m.ip+1,id,m.cursor,[]])
              m.ip = APP::Label[id]
            end
          end
        }]
      }
    ],

    [
      :RETURN,
      APP::Inst["RETURN", lambda{|m|
        ip,id,offs,elms = m.call_stack.pop
        key = [id, offs]

        if !m.leftrec?(id)
          # has no left recursive
          if m.return_value
            arg = APP::ActionArgument[id,offs,elms,m]
            act = m.actions[id]
            r = act ? [act.call(arg)] : []
            m.call_stack[-1][3] += r
            m.ip = ip
            m.memo[key] = [true, m.cursor, r]
          else
            m.ip = ip
            m.cursor = offs
            m.memo[key] = [false, offs, []]
          end
        else
          v = m.memo[key]
          m_ret, m_cur, m_r = v if v

          if !m.return_value || (m_cur && (m.cursor <= m_cur))
            # terminate seed growing
            if v
              m.return_value = m_ret
              m.cursor = m_cur
              m.call_stack[-1][3] += m_r
            else
              m.memo[key] = [false, offs, []]
              m.cursor = offs
            end

            m.ip = ip
            m.call_count[key] -= 1
          else
            # continue seed growing
            arg = APP::ActionArgument[id,offs,elms,m]
            act = m.actions[id]
            r = act ? [act.call(arg)] : []
            m.memo[key] = [m.return_value, m.cursor, r]

            m.cursor = offs
            m.ip = ip-1
            m.call_count[key] -= 1
          end
        end
      }]
    ],

    [
      :PUSHCONT,
      lambda{|id|
        s = "PUSHCONT (jump_to=%s)" % [APP::Helper.to_string(id)]
        APP::Inst[s, lambda{|m|
          m.cont_stack.push(APP::Cont[m, APP::Label[id]])
          m.incl
        }]
      }
    ],

    [
      :POPCONT,
      APP::Inst["POPCONT", lambda{|m|
        m.cont_stack.pop
        m.incl
      }]
    ],

    [
      :JUMP,
      lambda{|id|
        APP::Inst["JUMP (#{id})", lambda{|m|
          m.ip = APP::Label[id]
        }]
      }
    ],

    [
      :INTERRUPT,
      APP::Inst["INTERRUPT", lambda{|m|
        m.interrupt
      }]
    ],

    [
      :NEW_COUNTER,
      APP::Inst["NEW_COUNTER", lambda{|m|
        m.counter_stack.push(0)
        m.incl
      }]
    ],

    [
      :DELETE_COUNTER,
      APP::Inst["DELETE_COUNTER", lambda{|m|
        m.counter_stack.pop
        m.incl
      }]
    ],

    [
      :INCL_COUNTER,
      APP::Inst["INCL_COUNTER", lambda{|m|
        m.counter_stack[-1] += 1
        m.incl
      }]
    ],

    [
      :ASSERT_RETURN_VALUE_TRUE,
      APP::Inst["ASSERT_RETURN_VALUE (TRUE)", lambda{|m|
        m.return_value ? m.incl : m.interrupt
      }]
    ],

    [
      :ASSERT_COUNTER_EQ_0,
      APP::Inst["ASSERT_COUNTER (==0)", lambda{|m|
        m.counter_stack[-1] == 0 ? m.incl : m.interrupt
      }]
    ],

    [
      :ASSERT_COUNTER_EQ_1,
      APP::Inst["ASSERT_COUNTER (==1)", lambda{|m|
        m.counter_stack[-1] == 1 ? m.incl : m.interrupt
      }]
    ],

    [
      :ASSERT_COUNTER_GT_0,
      APP::Inst["ASSERT_COUNTER (>0)", lambda{|m|
        m.counter_stack[-1] > 0 ? m.incl : m.interrupt
      }]
    ],

    [
      :ASSERT_COUNTER_GTE_0,
      APP::Inst["ASSERT_COUNTER (>=0)", lambda{|m|
        m.counter_stack[-1] >= 0 ? m.incl : m.interrupt
      }]
    ],

    [
      :CHAR,
      lambda{|char_class|
        h = {}
        char_class.chars.each{|c| h[c] = true }
        APP::Inst["CHAR (#{char_class.inspect})", lambda{|m|
          if (c = m.readchar(m.cursor)) && h[c]
            m.cursor += 1
            m.incl
          else
            m.interrupt
          end
        }]
      }
    ],

    [
      :CHAR_ANY,
      APP::Inst["CHAR (ANY)", lambda{|m|
        if m.readchar(m.cursor)
          m.cursor += 1
          m.incl
        else
          m.interrupt
        end
      }]
    ],

    [
      :STRING,
      lambda{|str|
        APP::Inst["STRING (#{str})", lambda{|m|
          len = str.length
          if m.read(m.cursor,len) == str
            m.cursor += len
            m.incl
          else
            m.interrupt
          end
        }]
      }
    ],

    [
      :SET_RETURN_VALUE_TRUE,
      APP::Inst["SET_RETURN_VALUE (TRUE)", lambda{|m|
        m.return_value = true
        m.incl
      }]
    ],

    [
      :SET_RETURN_VALUE_FALSE,
      APP::Inst["SET_RETURN_VALUE (FALSE)", lambda{|m|
        m.return_value = false
        m.incl
      }]
    ],

  ].each{|e| const_set(*e)}
end
