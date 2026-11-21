module infer_walrus_string_01_m
    implicit none
contains
    function name() result(r)
        character(:), allocatable :: r
        r = "Mod::ILogger"
    end function

    subroutine check(str)
        character(*), intent(in) :: str
        integer :: n
        ! An assumed-length dummy.
        key := str
        if (len(key) /= 5 .or. key /= "xy   ") error stop 1
        ! Deferred-length results of a function and of trim.
        k1 := name()
        if (len(k1) /= 12 .or. k1 /= "Mod::ILogger") error stop 2
        k2 := trim(str)
        if (len(k2) /= 2 .or. k2 /= "xy") error stop 3
        ! A length computed at run time.
        n = 4
        k3 := repeat("a", n) // str
        if (len(k3) /= 9 .or. k3 /= "aaaaxy   ") error stop 4
        ! The variables are allocatable: assignment reallocates them.
        k1 = "a longer value"
        if (len(k1) /= 14 .or. k1 /= "a longer value") error stop 5
        key = "z"
        if (len(key) /= 1 .or. key /= "z") error stop 6
        ! A constant length stays constant.
        c := "ab" // "c"
        if (len(c) /= 3 .or. c /= "abc") error stop 7
        c = "abcdef"
        if (len(c) /= 3 .or. c /= "abc") error stop 8
    end subroutine
end module

program infer_walrus_string_01
    use infer_walrus_string_01_m
    implicit none
    call check("xy   ")
    print *, "PASSED"
end program
