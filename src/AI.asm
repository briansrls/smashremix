// AI.asm (by bit)
if !{defined __AI__} {
define __AI__()
print "included AI.asm\n"

// @ Description
// This file includes things that make the AIs/CPUs suck a little less.

include "Global.asm"
include "Toggles.asm"
include "OS.asm"

scope AI {

    // @ Description
    // All Computers Are Level 9 By Default [Mada0]
    pushvar origin, base
    origin 0x42D38
    db     0x09
    origin 0x42DAC
    db     0x09
    origin 0x42E20
    db     0x09
    origin 0x42E94
    db     0x09
    pullvar base, origin

    // @ Description
    // This removes the up b check allowing the CPU to recover multiple times [bit].
    scope recovery_fix_: {
        OS.patch_start(0x000AFFBC, 0x8013557C)
        jal     recovery_fix_._guard
        nop                                 // original line 2
        OS.patch_end()

        _original:
        // if here, improved AI is off, so we use the original logic
        bnez    t1, _j_0x80135628           // original line 1 (modified to branch to jump)
        nop
        jr      ra
        nop

        _guard:
        addiu   v1, r0, 0x0004
        li      at, SinglePlayerModes.singleplayer_mode_flag       // at = Mode Flag Address
        lw      at, 0x0000(at)              // at = 4 if Remix 1p
		beq     at, v1, _remix_1p           // if Remix 1p, automatic advanced ai
        nop
        Toggles.guard(Toggles.entry_improved_ai, _original)

        // if here, improved AI is on, so we skip the up b check
        _remix_1p:
        jr      ra
        nop

        _j_0x80135628:
        j       0x80135628                  // jump to 0x80135628
        nop
    }

    // @ Description
    // Chance to execute various rolls / 100
    constant CHANCE_FORWARD(30)
    constant CHANCE_BACKWARD(30)
    constant CHANCE_IN_PLACE(30)
    
    // @ Description
    // Chance to roll
    constant CHANCE_Z_CANCEL(95) 

    // @ Description
    // Functions that execute different tech options
    // @ Arguments
    // a0 - address of player struct
    // a1 - enum direction (forward = 0x49, backward), if applicable
    constant tech_roll_(0x80144700)
    constant tech_roll_og_(0x80144760)
    constant tech_in_place_(0x80144660)
    constant tech_in_place_og_(0x801446BC)
    constant tech_fail_(0x80144498)
    constant FORWARD(0x49)
    constant BACKWARD(0x4A)

    // @ Description
    // Helper for toggle guard
    scope j_random_teching__orginal_: {
        j       random_teching_._original
        nop
    }

    scope random_teching_: {
        OS.patch_start(0x000BB3C0, 0x80140980)
        jal     random_teching_
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        OS.patch_end()

        OS.patch_start(0x000BE034, 0x801435F4)
        jal     random_teching_
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        OS.patch_end()

        addiu   sp, sp,-0x0018              // allocate stack space
        sw      ra, 0x0014(sp)              // save ra

        addiu   t1, r0, 0x0004
        li      t0, SinglePlayerModes.singleplayer_mode_flag       // t0 = multiman flag
        lw      t0, 0x0000(t0)              // t0 = 4 if Remix 1p
		beq     t0, t1, _remix_1p           // if Remix 1p, automatic advanced ai
        nop
        Toggles.guard(Toggles.entry_improved_ai, j_random_teching__orginal_)

        _remix_1p:
        li      t0, Global.current_screen   // t0 = address of current screen
        lbu     t0, 0x0000(t0)              // t0 = current screen
        lli     t1, 0x003C                  // t1 = how to play screen id
        beq     t1, t0, _original           // if we're on the how to play screen,
        nop                                 // then skip all this

        li      t0, Global.match_info       // ~
        lw      t0, 0x0000(t0)              // t0 = address of match_info (0x800A4D08 in VS.)
        addiu   t0, t0, Global.vs.P_OFFSET  // t0 = address of first player sturct
        
        _loop:
        lbu     t2, 0x0002(t0)              // t2 = enum (man, cpu, none)
        lli     t1, 0x0002                  // t1 = none
        beql    t1, t2, _loop               // if (port is empty), go to next port
        addiu   t0, t0, Global.vs.P_DIFF    // else, increment pointer and loop
        lw      t1, 0x0058(t0)              // t0 = px struct
        beq     t1, s0, _cpu_check          // if (px = p_teched), continue (compare player structs)
        nop
        addiu   t0, t0, Global.vs.P_DIFF    // else, increment pointer and loop
        b       _loop
        nop
        
        _cpu_check:
        beqz    t2, _original               // if (t2 == man), skip
        nop
        lli     a0, 000100                  // ~
        jal     Global.get_random_int_      // v0 = (0-99)
        nop
        
        _roll_forward:
        sltiu   t1, v0, CHANCE_FORWARD
        beqz    t1, _roll_backward          // if out of range, skip
        nop                                 // else, continue
        move    a0, s0                      // a0 - player struct
        lli     a1, FORWARD                 // a1 - enum direction
        jal     tech_roll_                  // tech roll
        nop
        b       _end                        // end
        nop

        _roll_backward:
        sltiu   t2, v0, (CHANCE_FORWARD + CHANCE_BACKWARD)
        beqz    t2, _in_place               // if out of range, skip
        nop                                 // else, continue
        move    a0, s0                      // a0 - player struct
        lli     a1, BACKWARD                // a1 - enum direction
        jal     tech_roll_                  // tech roll
        nop
        b       _end                        // end
        nop

        _in_place:
        sltiu t2, v0, (CHANCE_FORWARD + CHANCE_BACKWARD + CHANCE_IN_PLACE)
        beqz    t2, _fail                   // if out of range, skip
        nop                                 // else, continue
        move    a0, s0                      // a0 - player struct
        jal     tech_in_place_              // tech in place
        nop
        b       _end                        // end
        nop
        
        _fail:
        move    a0, s0                      // a0 - player struct
        jal     tech_fail_                  // don't tech
        nop
        b       _end
        nop
        
        _original:
        jal     tech_roll_og_               // original line 1
        move    a0, s0                      // original line 2
        bnezl   v0, _end                    // original line 3
        nop                                 // original line 4
        jal     tech_in_place_og_           // original line 5
        move    a0, s0                      // original line 6
        bnezl   v0, _end                    // original line 7
        nop                                 // original line 8
        jal     tech_fail_                  // original line 9
        move    a0, s0                      // original line 10
        nop                                 // original line 11
        
        _end:
        lw      ra, 0x0014(sp)              // restore ra
        addiu   sp, sp, 0x0018              // deallocate stack space
        jr      ra                          // return
        nop
    }


    // @ Description
    // Usually, this function checks for a z-cancel press with 10 frames. At the end of this, at
    // holds a boolean for successful z-cancel. This function has been modified to make sure that
    // boolean is true for CPUs (Z_CANCEL_CHANCE)% of the time. [bit]
    scope z_cancel_: {
        OS.patch_start(0x000CB478, 0x80150A38)
        jal     z_cancel_
        nop
        OS.patch_end()

        _original:
        lw      t6, 0x0160(v1)              // original line 1
        slti    at, t6, 0x000B              // original line 2
        
        addiu   sp, sp,-0x0010              // allocate stack space
        sw      t0, 0x0004(sp)              // ~
        sw      t1, 0x0008(sp)              // save registers
        
        addiu   t1, r0, 0x0004
        li      t0, SinglePlayerModes.singleplayer_mode_flag       // at = multiman flag
        lw      t0, 0x0000(t0)              // at = 4 if Remix 1p
		beq     t0, t1, _remix_1p           // if Remix 1p, automatic advanced ai
        nop 
        
        lw      t0, 0x0004(sp)              // ~
        lw      t1, 0x0008(sp)              // save registers
        addiu   sp, sp, 0x0010              // deallocate stack space
        
        j       _normal
        nop
        
        _remix_1p:
        lw      t0, 0x0004(sp)              // ~
        lw      t1, 0x0008(sp)              // save registers
        addiu   sp, sp, 0x0010              // deallocate stack space
        j       _skip_toggle
        nop
        

        _normal:
        Toggles.guard(Toggles.entry_improved_ai, OS.NULL)

        _skip_toggle:
        addiu   sp, sp,-0x0020              // allocate stack space
        sw      ra, 0x001C(sp)              // ~
        sw      v0, 0x0010(sp)              // ~
        sw      v1, 0x0014(sp)              // ~
        sw      a0, 0x0018(sp)              // save registers

        li      t0, Global.current_screen   // t0 = address of current screen
        lbu     t0, 0x0000(t0)              // t0 = current screen
        lli     t1, 0x003C                  // t1 = how to play screen id
        beq     t1, t0, _end                // if we're on the how to play screen,
        nop                                 // then skip all this

        li      t0, Global.match_info       // ~
        lw      t0, 0x0000(t0)              // t0 = address of match_info (0x800A4D08 in VS.)
        addiu   t0, t0, Global.vs.P_OFFSET  // t0 = address of first player sturct
        
        _loop:
        lbu     t2, 0x0002(t0)              // t2 = enum (man, cpu, none)
        lli     t1, 0x0002                  // t1 = none
        beql    t1, t2, _loop               // if (port is empty), go to next port
        addiu   t0, t0, Global.vs.P_DIFF    // else, increment pointer and loop
        lw      t1, 0x0058(t0)              // t0 = px struct
        beq     t1, a0, _cpu_check          // if (px = p_teched), continue (compare player structs)
        nop
        addiu   t0, t0, Global.vs.P_DIFF    // else, increment pointer and loop
        b       _loop
        nop
        
        _cpu_check:
        beqz    t2, _end                    // if (t2 == man), skip
        nop
        lli     a0, 000100                  // ~
        jal     Global.get_random_int_      // v0 = (0-99)
        nop

        _cancel:
        sltiu   t1, v0, CHANCE_Z_CANCEL     // ~
        beqz    t1, _no_cancel              // if (v0 >= Z_CANCEL_CHANCE), set false
        nop
        lli     at, OS.TRUE                 // set true
        b       _end                        // end
        nop
    
        _no_cancel:
        lli     at, OS.FALSE                // set false
        b       _end                        // end
        nop

        _end:
        lw      ra, 0x001C(sp)              // ~
        lw      v0, 0x0010(sp)              // ~
        lw      v1, 0x0014(sp)              // ~
        lw      a0, 0x0018(sp)              // save registers
        addiu   sp, sp, 0x0020              // deallocate stack space
        jr      ra                          // return 
        nop
    }

}

} // __AI__
