! R1123 loop-control is [ , ] do-variable = scalar-int-expr, scalar-int-expr [ , scalar-int-expr ]
!                     or [ , ] WHILE ( scalar-logical-expr )
!                     or [ , ] CONCURRENT concurrent-header concurrent-locality
subroutine r1123_missing_bound()
    implicit none
    integer :: i
    do i = 1   ! {error R1123 missing-bound}
    end do
end subroutine
subroutine r1123_while_without_parens()
    implicit none
    integer :: n
    n = 0
    do while n < 3   ! {error R1123 while-without-parens}
        n = n + 1
    end do
end subroutine
subroutine r1123_four_exprs()
    implicit none
    integer :: i
    do i = 1, 10, 2, 3   ! {error R1123 four-exprs}
    end do
end subroutine
subroutine r1123_concurrent_without_header()
    implicit none
    integer :: i
    do concurrent   ! {error R1123 concurrent-without-header}
    end do
end subroutine
