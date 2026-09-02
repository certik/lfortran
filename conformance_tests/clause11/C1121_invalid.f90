! C1121 (R1124) The do-variable shall be a variable of type integer.
subroutine c1121_real()
    implicit none
    real :: x
    do x = 1.0, 3.0   ! {error C1121 real}
    end do
end subroutine
subroutine c1121_logical()
    implicit none
    logical :: l
    do l = 1, 3   ! {error C1121 logical}
    end do
end subroutine
subroutine c1121_character()
    implicit none
    character :: c
    do c = 1, 3   ! {error C1121 character}
    end do
end subroutine
subroutine c1121_real_dummy(x)
    implicit none
    real, intent(inout) :: x
    do x = 1.0, 3.0   ! {error C1121 real-dummy}
    end do
end subroutine
